FROM ubuntu/apache2
LABEL authors="barber"

RUN apt update && apt install -y libapache2-mod-auth-openidc ca-certificates python3-boto3 && a2enmod auth_openidc proxy proxy_http proxy_wstunnel rewrite headers && \
    sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf

COPY write_site.py /usr/local/bin/

CMD ["/bin/bash", "-c", "python3 /usr/local/bin/write_site.py && apache2-foreground"]
