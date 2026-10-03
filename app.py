from flask import Flask, render_template, request

app = Flask(__name__)

@app.route("/")
def home():
    return render_template("login.html")

@app.route("/login", methods=["POST"])
def login():
    username = request.form["username"]
    role = request.form["role"]

    return f"Welcome {username}! Role: {role}"

if __name__ == "__main__":
    app.run(debug=True)
