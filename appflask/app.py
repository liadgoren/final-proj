from flask import Flask
from markupsafe import escape

app = Flask(__name__)


@app.route("/hello/<name>")
def hello_name(name):
    response = app.make_response(f"Hello {escape(name)}!\n")
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    return response


@app.route("/healthz")
def healthz():
    return {"status": "ok"}, 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=False)
