import os
import mysql.connector
from flask import Flask, request, redirect, url_for, render_template
from cryptography import x509
from cryptography.hazmat.backends import default_backend

# ─── Config from Secrets ─────────────────────────────────────────────
DB_HOST   = os.environ.get("DB_HOST", "mysql")
DB_NAME   = os.environ["DB_NAME"]
#MESSAGE   = os.environ.get("MESSAGE", "Welcome to the Guestbook!")
CERT_FILE = "/tls/tls.crt"
KEY_FILE  = "/tls/tls.key"

def get_db_creds():
    user = open("/secrets/db/username").read().strip()
    pwd  = open("/secrets/db/password").read().strip()
    return user, pwd

def get_connection():
    user, pwd = get_db_creds()
    return mysql.connector.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=user,
        password=pwd
    ), user, pwd

def load_config(path="/secrets/config"):
    data = {}
    if not os.path.isdir(path):
        print(f"[load_config] {path} not found or not a dir")
        return data
    for fname in os.listdir(path):
        fpath = os.path.join(path, fname)
        if os.path.isfile(fpath):
            with open(fpath) as f:
                value = f.read().strip()
                data[fname] = value
                print(f"[load_config] loaded {fname} = {value!r}")
        else:
            print(f"[load_config] skipped non-file: {fpath}")
    print(f"[load_config] final CONFIG = {data}")
    return data



app = Flask(__name__)

@app.route("/", methods=["GET","POST"])
def index():
    conn, db_user, db_pass = get_connection()
    cur = conn.cursor()

    if request.method == "POST":
        name    = request.form.get("name","").strip()
        message = request.form.get("message","").strip()
        if name and message:
            cur.execute(
                "INSERT INTO guestbook (name,message) VALUES (%s,%s)",
                (name, message)
            )
            conn.commit()
        return redirect(url_for("index"))

    cur.execute("SELECT name,message,created_at FROM guestbook ORDER BY id DESC")
    entries = cur.fetchall()
    cur.close()
    conn.close()

    # Parse cert
    with open(CERT_FILE,"rb") as f:
        pem = f.read()
    cert = x509.load_pem_x509_certificate(pem, default_backend())
    serial  = format(cert.serial_number,"x").upper()
    expires = cert.not_valid_after.isoformat()

    # Parse Secrets
    CONFIG = load_config()

    return render_template(
        "index.html",
        serial=serial,
        expires=expires,
        db_user=db_user,
        lease_id=db_pass,
        vault_message=CONFIG.get("message", "None Found."),
        vault_secret=CONFIG.get("supersecretpassword", "NA"),
        rows=entries
    )

if __name__ == "__main__":
    ssl_ctx = (CERT_FILE, KEY_FILE)
    app.run(host="0.0.0.0", port=5000, ssl_context=ssl_ctx)
