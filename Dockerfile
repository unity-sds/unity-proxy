FROM ubuntu/apache2
LABEL authors="barber"

RUN apt update && apt install -y libapache2-mod-auth-openidc ca-certificates && a2enmod auth_openidc proxy proxy_http proxy_wstunnel rewrite headers && \
    sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf

COPY write_site.sh /usr/local/bin/

CMD ["/bin/bash", "-c", "/usr/local/bin/write_site.sh && apache2-foreground"]
