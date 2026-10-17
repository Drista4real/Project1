"""WebDriver lifecycle and failure evidence, separate from backend/ML pytest."""

import json
import os
import re
from pathlib import Path
from urllib.parse import urlsplit

import pytest
from selenium import webdriver


@pytest.fixture
def browser(request):
    name = os.environ.get("BROWSER_TEST_NAME")
    base_url = os.environ.get("BROWSER_TEST_BASE_URL", "")
    address = urlsplit(base_url)
    if name not in {"chrome", "edge", "firefox"} or (
        address.scheme != "http" or address.hostname != "127.0.0.1"
    ):
        pytest.fail("Use tests/browser/run.py to start the isolated local server.")

    artifacts = Path(os.environ["BROWSER_TEST_ARTIFACTS"])
    artifacts.mkdir(parents=True, exist_ok=True)
    options_type = {
        "chrome": webdriver.ChromeOptions,
        "edge": webdriver.EdgeOptions,
        "firefox": webdriver.FirefoxOptions,
    }[name]
    options = options_type()
    if os.environ.get("BROWSER_TEST_HEADLESS", "true") == "true":
        options.add_argument("-headless" if name == "firefox" else "--headless=new")
    if name in {"chrome", "edge"}:
        options.add_argument("--window-size=1440,1000")
        options.add_argument("--disable-search-engine-choice-screen")
        options.set_capability("goog:loggingPrefs", {"browser": "ALL"})
    else:
        options.set_preference("gfx.webrender.software", True)

    # Each test gets a fresh temporary browser profile from WebDriver.
    factory = {
        "chrome": webdriver.Chrome,
        "edge": webdriver.Edge,
        "firefox": webdriver.Firefox,
    }[name]
    driver = factory(options=options)
    request.node.browser_driver = driver
    request.node.browser_artifacts = artifacts
    try:
        driver.set_page_load_timeout(60)
        driver.set_script_timeout(15)
        driver.set_window_size(1440, 1000)
        metadata = {
            "browser": name,
            "browserVersion": driver.capabilities.get("browserVersion"),
            "platformName": driver.capabilities.get("platformName"),
            "driver": driver.capabilities.get("chrome", {}).get("chromedriverVersion")
            or driver.capabilities.get("msedge", {}).get("msedgedriverVersion")
            or driver.capabilities.get("moz:geckodriverVersion"),
        }
        (artifacts / "browser.json").write_text(
            json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
        )
        driver.get(base_url)
        yield driver
    finally:
        driver.quit()


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    result = yield
    report = result.get_result()
    if not report.failed or not hasattr(item, "browser_driver"):
        return
    driver = item.browser_driver
    artifacts = item.browser_artifacts
    name = re.sub(r"[^A-Za-z0-9_-]+", "_", item.nodeid)
    # Evidence failure must not hide the original test failure.
    try:
        driver.save_screenshot(str(artifacts / f"{name}.png"))
        (artifacts / f"{name}.html").write_text(driver.page_source, encoding="utf-8")
        (artifacts / f"{name}.console.json").write_text(
            json.dumps(driver.get_log("browser"), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    except Exception as error:
        (artifacts / f"{name}.evidence-error.txt").write_text(
            str(error), encoding="utf-8"
        )
