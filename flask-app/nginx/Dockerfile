FROM nginx:1.18.0
RUN rm /etc/nginx/nginx.conf
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/
COPY flask-app.conf /etc/nginx/conf.d/
