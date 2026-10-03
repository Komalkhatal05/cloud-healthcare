from flask import Flask, render_template, request

app = Flask(__name__)

@app.route("/")
def home():
    return render_template("login.html")

@app.route("/login", methods=["POST"])
def login():
    username = request.form["username"]
    role = request.form["role"]

    if role == "patient":
        return render_template("patient_dashboard.html", username=username)

    elif role == "doctor":
        return render_template("doctor_dashboard.html", username=username)

    return "Invalid role"

if __name__ == "__main__":
    app.run(debug=True)
