# ============================================================
# Etapa 1
# ============================================================
FROM drupal:10

RUN apt-get update && \
    apt-get install -y unzip git zip && \
    rm -rf /var/lib/apt/lists/*
  
# Copia composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-progress

COPY . .
RUN chown -R www-data:www-data /app


# ============================================================
# Etapa 2 
# ============================================================


# Configura repositório completo e instala pacotes de utilidade
RUN apt-get update && apt-get install -y \
    apt-transport-https ca-certificates gnupg curl nano vim less wget procps mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Ajusta PHP: ativa extensões que o Drupal usa
RUN docker-php-ext-install pdo_mysql opcache

WORKDIR /var/www/html
RUN chown -R www-data:www-data /var/www/html

# Ajusta permissões e cria diretórios
RUN mkdir -p sites/default/files sites/default/private \
    && chown -R www-data:www-data sites/default \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

# Configura Apache para permitir .htaccess
RUN sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Define ServerName para evitar warning
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Ativa módulos do Apache usados pelo Drupal
RUN a2enmod rewrite expires headers


# Instala Drush globalmente
RUN composer global require drush/drush \
    && ln -s /root/.composer/vendor/bin/drush /usr/local/bin/drush


EXPOSE 80

CMD ["apache2-foreground"]
