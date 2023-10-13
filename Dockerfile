# Use the official PHP 8.2 image as a base
FROM php:8.1-apache as base

WORKDIR /app

# Install the necessary dependencies for compiling PHP extensions
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    libxml2-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libicu-dev \
    zlib1g-dev \
    libpng-dev \
    libjpeg-dev \
    libxslt1-dev \
    libc-client-dev \
    libkrb5-dev \
    wget \
    unzip \
    git && \
    rm -rf /var/lib/apt/lists/*

# Enable mod_rewrite for Apache
RUN a2enmod rewrite && service apache2 restart

# Set ServerName to suppress the AH00558 warning
RUN echo "ServerName localhost" | tee /etc/apache2/conf-available/fqdn.conf && a2enconf fqdn

# Copy custom php.ini configuration to disable warnings and deprecations
COPY custom-php.ini /usr/local/etc/php/conf.d/custom-php.ini

FROM base as php-base

# Install the necessary PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) gd && \
    docker-php-ext-install mysqli && \
    docker-php-ext-install zip && \
    docker-php-ext-install soap && \
    docker-php-ext-install intl && \
    docker-php-ext-install xsl && \
    docker-php-ext-install opcache && \
    docker-php-ext-install exif && \
    docker-php-ext-install mbstring && \
    docker-php-ext-install xml && \
    docker-php-ext-install pdo_mysql && \
    pecl install apcu && docker-php-ext-enable apcu

RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
    docker-php-ext-install -j$(nproc) imap


FROM base as fetch-osticket

# Get release version for osTicket
RUN wget https://github.com/osTicket/osTicket/releases/download/v1.18/osTicket-v1.18.zip

# Unzip osTicket
RUN unzip osTicket-v1.18.zip

FROM php-base as osticket

## Copy osTicket files
COPY --from=fetch-osticket /app/upload/ /var/www/html/

## Copy sample config file
COPY ./include/ost-sampleconfig.php /var/www/html/include/ost-config.php

## Give write permission
RUN chmod 0666 /var/www/html/include/ost-config.php

# Expose port 80 for the Apache web server
EXPOSE 80

# Expose port 443 for the Apache web server
EXPOSE 443

# Start Apache in the foreground
CMD ["apache2-foreground"]
