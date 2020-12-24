FROM python:3.8-alpine
WORKDIR /code
RUN apk add --no-cache bash curl
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY src/ .
CMD ["flask", "run", "--host", "0.0.0.0"]
