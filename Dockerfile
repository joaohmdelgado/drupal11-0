#
# --- ETAPA 1: BUILDER (Cria o projeto e instala dependências) ---
# Usamos uma imagem cli para ter o ambiente PHP e o Composer de forma eficiente.
FROM php:8.2-cli AS builder

# Instala ferramentas necessárias para Composer/git, etc.
RUN apt-get update && \
    apt-get install -y git unzip zip --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Configura o diretório de trabalho do projeto (Usaremos /usr/src/drupal como ponto de montagem de código)
WORKDIR /usr/src/drupal

# Copia os arquivos de definição de dependência
COPY composer.json composer.lock ./

# Instala todas as dependências do Composer.
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-progress

# Copia o restante do código-fonte (este deve ser o diretório raiz do seu projeto)
COPY . .

# --- ETAPA 2: PRODUÇÃO (Cria a imagem final leve) ---
# Imagem oficial do Drupal que usa /opt/drupal/web como DOCUMENT ROOT
FROM drupal:10-apache

# O WORKDIR padrão é /opt/drupal/web, mas vamos usar a convenção da imagem base para onde o código deve ser copiado: /usr/src/drupal.

# ----------------------------------------------------
# 1. Instala utilidades essenciais (para MariaDB e debugging)
# ----------------------------------------------------
RUN apt-get update && apt-get install -y \
    mariadb-client \
    nano vim less procps \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# ----------------------------------------------------
# 2. Configura PHP e Apache
# ----------------------------------------------------
RUN docker-php-ext-install pdo_mysql opcache

# Configura e otimiza Apache
RUN sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf \
    && a2enmod rewrite expires headers

# ----------------------------------------------------
# 3. Copia CÓDIGO e DRUSH da etapa builder
# ----------------------------------------------------

# Copia todo o código-fonte COMPLETO e o diretório vendor da etapa builder
# O destino /usr/src/drupal/ é onde a imagem base espera encontrar o código-fonte COMPLETO do projeto.
COPY --from=builder /usr/src/drupal /usr/src/drupal

# Define o WORKDIR para a raiz da web, onde o Drush espera ser executado
WORKDIR /opt/drupal/web

# Instala o Drush globalmente (A imagem base já tem Composer disponível globalmente)
# Usaremos um WORKDIR temporário para que o link simbólico funcione corretamente
# E instalamos o drush no diretório global
RUN composer global require drush/drush \
    && ln -s /root/.composer/vendor/bin/drush /usr/local/bin/drush

# ----------------------------------------------------
# 4. Ajusta Permissões e Diretórios
# ----------------------------------------------------

# O código é uma cópia de referência. Aqui garantimos as permissões dentro da raiz web
RUN mkdir -p sites/default/files sites/default/private \
    && chown -R www-data:www-data sites/default \
    && chown -R www-data:www-data /usr/src/drupal \
    && find /usr/src/drupal -type d -exec chmod 755 {} \; \
    && find /usr/src/drupal -type f -exec chmod 644 {} \;

EXPOSE 80

# Comando padrão da imagem base do Drupal
CMD ["apache2-foreground"]
