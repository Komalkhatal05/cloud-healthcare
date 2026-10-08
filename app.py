cat > app.py <<'PY'
from flask import Flask, render_template, request, redirect, url_for, session
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash

app = Flask(__name__)

# =========================
# APPLICATION CONFIGURATION
# =========================

app.secret_key = "healthcare-project-secret-key"

app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///healthcare.db"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)


# =========================
# USER MODEL
# =========================

class User(db.Model):

    id = db.Column(
        db.Integer,
        primary_key=True
    )

    username = db.Column(
        db.String(100),
        unique=True,
        nullable=False
    )

    password = db.Column(
        db.String(255),
        nullable=False
    )

    role = db.Column(
        db.String(20),
        nullable=False
    )


# =========================
# PATIENT MODEL
# =========================

class Patient(db.Model):

    id = db.Column(
        db.Integer,
        primary_key=True
    )

    name = db.Column(
        db.String(100),
        nullable=False
    )

    age = db.Column(
        db.Integer
    )

    gender = db.Column(
        db.String(20)
    )

    disease = db.Column(
        db.String(200)
    )

    phone = db.Column(
        db.String(20)
    )


# =========================
# APPOINTMENT MODEL
# =========================

class Appointment(db.Model):

    id = db.Column(
        db.Integer,
        primary_key=True
    )

    patient_name = db.Column(
        db.String(100),
        nullable=False
    )

    doctor_name = db.Column(
        db.String(100),
        nullable=False
    )

    appointment_date = db.Column(
        db.String(50),
        nullable=False
    )

    reason = db.Column(
        db.String(300)
    )


# =========================
# CREATE DEFAULT USERS
# =========================

def create_default_users():

    default_users = [

        (
            "admin",
            "admin123",
            "Admin"
        ),

        (
            "doctor",
            "doctor123",
            "Doctor"
        ),

        (
            "patient",
            "patient123",
            "Patient"
        )

    ]

    for username, password, role in default_users:

        existing_user = User.query.filter_by(
            username=username
        ).first()

        if not existing_user:

            new_user = User(

                username=username,

                password=generate_password_hash(
                    password
                ),

                role=role
            )

            db.session.add(new_user)

    db.session.commit()


# =========================
# HOME / LOGIN PAGE
# =========================

@app.route("/")
def home():

    session.clear()

    return render_template(
        "login.html"
    )


# =========================
# REGISTER
# =========================

@app.route(
    "/register",
    methods=["GET", "POST"]
)
def register():

    if request.method == "POST":

        username = request.form.get(
            "username",
            ""
        ).strip()

        password = request.form.get(
            "password",
            ""
        )

        confirm_password = request.form.get(
            "confirm_password",
            ""
        )

        role = request.form.get(
            "role",
            ""
        )

        # Required field validation

        if not username or not password:

            return render_template(
                "register.html",
                error="All fields are required."
            )

        # Password validation

        if password != confirm_password:

            return render_template(
                "register.html",
                error="Passwords do not match."
            )

        # Role validation

        if role not in [
            "Patient",
            "Doctor",
            "Admin"
        ]:

            return render_template(
                "register.html",
                error="Please select a valid role."
            )

        # Check existing username

        existing_user = User.query.filter_by(
            username=username
        ).first()

        if existing_user:

            return render_template(
                "register.html",
                error="Username already exists."
            )

        # Create user

        new_user = User(

            username=username,

            password=generate_password_hash(
                password
            ),

            role=role
        )

        db.session.add(
            new_user
        )

        db.session.commit()

        return redirect(
            url_for("home")
        )

    return render_template(
        "register.html"
    )


# =========================
# LOGIN
# =========================

@app.route(
    "/login",
    methods=["POST"]
)
def login():

    username = request.form.get(
        "username",
        ""
    ).strip()

    password = request.form.get(
        "password",
        ""
    )

    role = request.form.get(
        "role",
        ""
    )

    user = User.query.filter_by(
        username=username
    ).first()

    # Check username and password

    if user and check_password_hash(
        user.password,
        password
    ):

        # Check selected role

        if user.role != role:

            return render_template(
                "login.html",
                error="Selected role does not match this account."
            )

        # Store session

        session["user_id"] = user.id

        session["username"] = user.username

        session["role"] = user.role

        # Redirect based on role

        if user.role == "Admin":

            return redirect(
                url_for("admin")
            )

        elif user.role == "Doctor":

            return redirect(
                url_for("doctor")
            )

        elif user.role == "Patient":

            return redirect(
                url_for("patient")
            )

    return render_template(
        "login.html",
        error="Invalid username or password."
    )


# =========================
# ADMIN DASHBOARD
# =========================

@app.route("/admin")
def admin():

    if "user_id" not in session:

        return redirect(
            url_for("home")
        )

    if session.get("role") != "Admin":

        return redirect(
            url_for("home")
        )

    patients = Patient.query.all()

    appointments = Appointment.query.all()

    return render_template(
        "admin.html",
        patients=patients,
        appointments=appointments
    )


# =========================
# DOCTOR DASHBOARD
# =========================

@app.route("/doctor")
def doctor():

    if "user_id" not in session:

        return redirect(
            url_for("home")
        )

    if session.get("role") != "Doctor":

        return redirect(
            url_for("home")
        )

    patients = Patient.query.all()

    appointments = Appointment.query.all()

    return render_template(
        "doctor_dashboard.html",
        patients=patients,
        appointments=appointments
    )


# =========================
# PATIENT DASHBOARD
# =========================

@app.route("/patient")
def patient():

    if "user_id" not in session:

        return redirect(
            url_for("home")
        )

    if session.get("role") != "Patient":

        return redirect(
            url_for("home")
        )

    appointments = Appointment.query.filter_by(
        patient_name=session["username"]
    ).all()

    return render_template(
        "patient_dashboard.html",
        appointments=appointments
    )


# =========================
# ADD PATIENT
# =========================

@app.route(
    "/add_patient",
    methods=["POST"]
)
def add_patient():

    if "user_id" not in session:

        return redirect(
            url_for("home")
        )

    if session.get("role") != "Admin":

        return redirect(
            url_for("home")
        )

    patient = Patient(

        name=request.form.get(
            "name"
        ),

        age=request.form.get(
            "age"
        ),

        gender=request.form.get(
            "gender"
        ),

        disease=request.form.get(
            "disease"
        ),

        phone=request.form.get(
            "phone"
        )
    )

    db.session.add(
        patient
    )

    db.session.commit()

    return redirect(
        url_for("admin")
    )


# =========================
# BOOK APPOINTMENT
# =========================

@app.route(
    "/book_appointment",
    methods=["POST"]
)
def book_appointment():

    if "user_id" not in session:

        return redirect(
            url_for("home")
        )

    if session.get("role") != "Patient":

        return redirect(
            url_for("home")
        )

    appointment = Appointment(

        patient_name=request.form.get(
            "patient_name"
        ),

        doctor_name=request.form.get(
            "doctor_name"
        ),

        appointment_date=request.form.get(
            "appointment_date"
        ),

        reason=request.form.get(
            "reason"
        )
    )

    db.session.add(
        appointment
    )

    db.session.commit()

    return redirect(
        url_for("patient")
    )


# =========================
# LOGOUT
# =========================

@app.route("/logout")
def logout():

    session.clear()

    return redirect(
        url_for("home")
    )


# =========================
# DATABASE INITIALIZATION
# =========================

with app.app_context():

    db.create_all()

    create_default_users()


# =========================
# RUN APPLICATION
# =========================

if __name__ == "__main__":

    app.run(
        host="127.0.0.1",
        port=5000,
        debug=True
    )
PY
