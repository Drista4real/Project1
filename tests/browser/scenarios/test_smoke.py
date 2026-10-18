"""Starter cross-browser checks against the actual compiled Flutter UI."""

import os
from pathlib import Path

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


def login_form(browser):
    element(browser, "auth-email")
    element(browser, "auth-password")


def fill(browser, identifier, value):
    field = element(browser, identifier)
    if field.tag_name not in {"input", "textarea"}:
        field = field.find_element(By.CSS_SELECTOR, "input,textarea")
    field.clear()
    field.send_keys(value)


def test_boots_real_flutter_app_and_prompts_for_login(browser):
    login_form(browser)
    element(browser, "auth-guest")
    assert "Kakeibo Zen" in browser.title
    see(browser, "Chào mừng trở lại")
    browser.save_screenshot(str(Path(os.environ["BROWSER_TEST_ARTIFACTS"]) / "auth-login.png"))


def test_private_route_reload_requires_authentication(browser):
    browser.get(browser.current_url.split("#")[0] + "#/settings")
    login_form(browser)
    browser.refresh()
    login_form(browser)
    see(browser, "Chào mừng trở lại")


def test_empty_login_validates_without_auth_request(browser):
    login_form(browser)
    click(browser, "auth-submit")
    see(browser, "Nhập email hợp lệ")
    see(browser, "Nhập mật khẩu")


def test_invalid_login_values_show_validation_errors(browser):
    login_form(browser)
    fill(browser, "auth-email", "not-an-email")
    fill(browser, "auth-password", "")
    click(browser, "auth-submit")
    see(browser, "Nhập email hợp lệ")
    see(browser, "Nhập mật khẩu")


def test_switch_between_login_and_registration(browser):
    login_form(browser)
    click(browser, "auth-toggle-mode")
    see(browser, "Tạo tài khoản")
    see(browser, "Đã có tài khoản? Đăng nhập")
    click(browser, "auth-submit")
    see(browser, "Nhập email hợp lệ")
    click(browser, "auth-toggle-mode")
    see(browser, "Chưa có tài khoản? Đăng ký")


@pytest.mark.parametrize("identifier,title", [
    ("auth-use-otp", "Đăng nhập bằng OTP"),
    ("auth-use-recovery", "Khôi phục mật khẩu"),
])
def test_email_code_modes_validate_before_sending(browser, identifier, title):
    login_form(browser)
    click(browser, identifier)
    see(browser, title)
    click(browser, "auth-submit")
    see(browser, "Nhập email hợp lệ")
