"""
长安大学统一身份认证平台 (IDS) 登录与会话管理
支持动态 Salt、AES-128-CBC 加密、验证码自适应检测
"""

import random
import base64
from urllib.parse import urljoin, quote
import requests
from bs4 import BeautifulSoup
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad

AES_CHARS = "ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678"

def _random_string(length: int) -> str:
    """生成指定长度的随机字符串（与 CHD encrypt.js 字典一致）"""
    return ''.join(random.choice(AES_CHARS) for _ in range(length))

def encrypt_password(password: str, salt: str) -> str:
    """复现 CHD IDS 前端 encryptPassword 逻辑：
    AES-128-CBC, PKCS7 padding, 64位随机前缀，16位随机IV，Base64编码
    """
    salt = salt.strip()
    iv = _random_string(16)
    prefix = _random_string(64)
    data = (prefix + password).encode('utf-8')
    key = salt.encode('utf-8')
    iv_bytes = iv.encode('utf-8')
    
    cipher = AES.new(key, AES.MODE_CBC, iv_bytes)
    padded = pad(data, AES.block_size, style='pkcs7')
    encrypted = cipher.encrypt(padded)
    return base64.b64encode(encrypted).decode('utf-8')

class CHDAuthSession:
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                          '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
        })
        self.service_url = 'http://bkjw.chd.edu.cn/eams/home.action'
        self.login_url = f'https://ids.chd.edu.cn/authserver/login?service={quote(self.service_url, safe="")}'

    def check_need_captcha(self, username: str) -> bool:
        """检测当前账号登录是否需要图形验证码"""
        try:
            url = f'https://ids.chd.edu.cn/authserver/checkNeedCaptcha.htl?username={username}'
            res = self.session.get(url, timeout=5)
            data = res.json()
            return bool(data.get('isNeed', False))
        except Exception:
            return False

    def is_session_alive(self) -> bool:
        """检查当前 session 是否仍然有效，避免频繁登录导致被校内风控锁定"""
        try:
            res = self.session.get(self.service_url, allow_redirects=False, timeout=5)
            if res.status_code == 200:
                return True
            loc = res.headers.get('Location', '')
            if res.status_code == 302 and 'authserver' not in loc:
                return True
            return False
        except Exception:
            return False

    def export_cookies(self) -> dict:
        """导出当前会话 Cookie 便于本地磁盘持久化"""
        return self.session.cookies.get_dict()

    def import_cookies(self, cookies: dict):
        """导入已有的 Cookie 恢复会话"""
        self.session.cookies.update(cookies)

    def login(self, username: str, password: str, captcha: str = "") -> dict:
        """执行全套统一身份认证与 EAMS 跳转登录
        返回: {"success": bool, "message": str, "cookies": dict}
        """
        try:
            # 1. 请求登录页面获取 Salt 与 Execution
            res = self.session.get(self.login_url, timeout=10)
            soup = BeautifulSoup(res.text, 'html.parser')

            pwd_form = soup.find('form', id='pwdFromId')
            if not pwd_form:
                # 可能已经处于登录状态
                if 'eams' in res.url:
                    return {"success": True, "message": "已在登录状态"}
                return {"success": False, "message": "无法定位登录表单，请稍后再试"}

            action = pwd_form.get('action') or '/authserver/login'
            if not action.startswith('http'):
                action = urljoin(res.url, action)
            if 'service=' not in action:
                action += f'?service={quote(self.service_url, safe="")}'

            salt_input = soup.find('input', id='pwdEncryptSalt')
            salt = salt_input.get('value') if salt_input else ''
            if not salt:
                return {"success": False, "message": "获取加密盐失败"}

            execution_input = pwd_form.find('input', attrs={'name': 'execution'})
            execution = execution_input.get('value') if execution_input else 'e1s1'

            # 2. 检查验证码要求
            need_captcha = self.check_need_captcha(username)
            if need_captcha and not captcha:
                return {"success": False, "need_captcha": True, "message": "需要输入验证码"}

            # 3. 加密密码
            enc_password = encrypt_password(password, salt)

            post_data = {
                'username': username,
                'password': enc_password,
                'captcha': captcha,
                '_eventId': 'submit',
                'cllt': 'userNameLogin',
                'dllt': 'generalLogin',
                'lt': '',
                'execution': execution
            }

            # 4. 提交登录
            login_res = self.session.post(action, data=post_data, allow_redirects=True, timeout=15)
            
            # 判断是否成功重定向至教务系统
            if 'bkjw.chd.edu.cn/eams' in login_res.url or 'home.action' in login_res.url:
                return {"success": True, "message": "登录成功"}
            
            # 解析失败提示信息
            err_soup = BeautifulSoup(login_res.text, 'html.parser')
            msg_el = err_soup.find(id='msg') or err_soup.find(class_='auth_error') or err_soup.find(class_='error-tips')
            err_msg = msg_el.get_text(strip=True) if msg_el else "学号或密码错误"
            return {"success": False, "message": err_msg}

        except Exception as e:
            return {"success": False, "message": f"登录请求异常: {str(e)}"}
