"""Starter cross-browser checks against the actual compiled Flutter UI."""

from urllib.parse import urlsplit

import pytest
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait

pytestmark = pytest.mark.smoke

# Flutter keeps semantics inside a shadow root. Inspect DOM roots only; do not
# reach into Dart state or bypass UI callbacks with JavaScript.
FIND_SEMANTIC = """
const selector = '[flt-semantics-identifier="' + arguments[0] + '"]';
function find(root) {
  const match = root.querySelector(selector);
  if (match) return match;
  for (const element of root.querySelectorAll('*')) {
    if (element.shadowRoot) {
      const nested = find(element.shadowRoot);
      if (nested) return nested;
    }
  }
  return null;
}
return find(document);
"""

READ_TEXT = """
function read(root) {
  let text = root.textContent || '';
  for (const element of root.querySelectorAll('*')) {
    text += '\\n' + (element.getAttribute('aria-label') || '');
    if (element.shadowRoot) text += '\\n' + read(element.shadowRoot);
  }
  return text;
}
return read(document.body);
"""


def element(browser, identifier):
    return WebDriverWait(browser, 40).until(
        lambda driver: driver.execute_script(FIND_SEMANTIC, identifier)
    )


def click(browser, identifier):
    target = element(browser, identifier)
    WebDriverWait(browser, 10).until(
        lambda _: target.is_displayed() and target.is_enabled()
    )
    target.click()


def see(browser, text):
    WebDriverWait(browser, 15).until(
        lambda driver: text in driver.execute_script(READ_TEXT)
    )


def wait_for_route(browser, route):
    WebDriverWait(browser, 15).until(
        lambda driver: (urlsplit(driver.current_url).fragment or "/") == route,
        message=f"Expected browser route {route}",
    )


def login_form(browser):
    click(browser, "ledger-sign-in")
    element(browser, "auth-email")
    element(browser, "auth-password")


def fill(browser, identifier, value):
    field = element(browser, identifier)
    if field.tag_name not in {"input", "textarea"}:
        field = field.find_element(By.CSS_SELECTOR, "input,textarea")
    field.clear()
    field.send_keys(value)


def test_boots_real_flutter_app_and_prompts_for_login(browser):
    element(browser, "nav-ledger")
    element(browser, "ledger-sign-in")
    assert "Kakeibo Zen" in browser.title
    see(browser, "Vui lòng đăng nhập để quản lý tài chính.")


def test_navigation_changes_routes_and_survives_reload(browser):
    for identifier, route in [
        ("nav-reports", "/reports"),
        ("nav-budget", "/budget"),
        ("nav-settings", "/settings"),
        ("nav-ledger", "/"),
    ]:
        click(browser, identifier)
        wait_for_route(browser, route)
    click(browser, "nav-settings")
    # Flutter updates browser history asynchronously after the WebDriver click.
    # Reload only once the destination URL and its page content are present.
    wait_for_route(browser, "/settings")
    see(browser, "Tiện Ích và Cài Đặt")
    browser.refresh()
    wait_for_route(browser, "/settings")
    see(browser, "Tiện Ích và Cài Đặt")


def test_empty_login_validates_without_auth_request(browser):
    login_form(browser)
    click(browser, "auth-submit")
    see(browser, "Nhập email hợp lệ")
    see(browser, "Nhập mật khẩu ít nhất 6 ký tự")


def test_invalid_login_values_show_validation_errors(browser):
    login_form(browser)
    fill(browser, "auth-email", "not-an-email")
    fill(browser, "auth-password", "123")
    click(browser, "auth-submit")
    see(browser, "Nhập email hợp lệ")
    see(browser, "Nhập mật khẩu ít nhất 6 ký tự")


def test_switch_between_login_and_registration(browser):
    login_form(browser)
    click(browser, "auth-toggle-mode")
    see(browser, "Tạo tài khoản")
    see(browser, "Đã có tài khoản? Đăng nhập")
    click(browser, "auth-submit")
    see(browser, "Nhập email hợp lệ")
    click(browser, "auth-toggle-mode")
    see(browser, "Chưa có tài khoản? Đăng ký")
