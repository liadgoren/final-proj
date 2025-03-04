FROM alpine:3.21.2
WORKDIR /app

# התקנת Python ו-Pip
RUN apk update
RUN apk add python3 
RUN apk add --no-cache python3 py3-pip

# יצירת סביבת עבודה וירטואלית
RUN python -m venv /app/venv 
ENV PATH="/app/venv/bin:$PATH"

# ✅ מעתיקים קודם את קובץ ה- requirements.txt כדי לנצל את Cache בצורה חכמה
COPY ./requirements.txt /app
RUN pip install -r requirements.txt

# ✅ מעתיקים את קובצי הקוד אחרי ההתקנה (כדי ש-Docker יבין שהם שונים אם יש עדכון)
COPY ./app.py /app
COPY ./test_app.py /app  # מועתק מחדש בכל בנייה כדי למנוע שימוש בגרסה ישנה!

# הפעלת האפליקציה
CMD ["python3", "app.py"]
