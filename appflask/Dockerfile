FROM alpine:3.21.2
WORKDIR /app

RUN apk update
RUN apk add python3 
RUN apk add --no-cache python3 py3-pip

RUN python -m venv /app/venv 
ENV PATH="/app/venv/bin:$PATH"

COPY ./requirements.txt /app
RUN pip install -r requirements.txt

COPY ./app.py /app
COPY ./test_app.py /app  # מועתק מחדש בכל בנייה כדי למנוע שימוש בגרסה ישנה!

CMD ["python3", "app.py"]
