FROM swaggerapi/swagger-ui

COPY conf/interceptors.js /usr/share/nginx/configurator/interceptors.js

RUN configurator=/usr/share/nginx/configurator; \
    index="${configurator}/index.js"; \
    interceptors="${configurator}/interceptors.js"; \
    search='SwaggerUIBundle({'; \
    replace="${search} $(cat ${interceptors} | tr -d '\n')"; \
    sed -i "s|${search}|${replace}|g" "${index}"