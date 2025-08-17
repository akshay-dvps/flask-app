from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/health", methods=["GET"])
def health():
    return "200 OK", 200

@app.route("/data", methods=["GET"])
def data():
    return "Helldev from DevOps!", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

