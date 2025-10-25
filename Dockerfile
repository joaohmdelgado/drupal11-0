#
# --- ETAPA 1: BUILDER (Cria o projeto e instala dependências) ---
# Usamos uma imagem cli para ter o ambiente PHP limpo para o Composer.
FROM php:8.2-cli AS builder

# O Composer precisa estar disponível para o comando 'composer install'.
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Instala ferramentas necessárias para Composer/git, etc.
RUN apt-get update && \
    apt-get install -y git unzip zip libpng-dev libjpeg-dev libwebp-dev --no-install-recommends && \
    docker-php-ext-install gd && \
    rm -rf /var/lib/apt/lists/*
    

# Configura o diretório de trabalho do projeto (Raiz do Composer)
WORKDIR /usr/src/drupal

# Copia os arquivos de definição de dependência
COPY composer.json composer.lock ./

# Instala todas as dependências do Composer.
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-progress

# Copia o restante do código-fonte
COPY . .

# --- ETAPA 2: PRODUÇÃO (Cria a imagem final leve e pronta para rodar) ---
# Imagem oficial do Drupal que usa /opt/drupal/web como DOCUMENT ROOT
FROM drupal:10-apache

# O WORKDIR padrão é /opt/drupal/web, mas as convenções da imagem base
# colocam o código-fonte COMPLETO em /usr/src/drupal.

# ----------------------------------------------------
# 1. Instala utilidades essenciais
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

# Copia todo o código-fonte COMPLETO e o diretório vendor (criado na etapa builder)
COPY --from=builder --chown=www-data:www-data /usr/src/drupal /opt/drupal

# Define o WORKDIR para a raiz da web do Drupal (Document Root)
WORKDIR /opt/drupal

# Adiciona o diretório de binários do Composer (.vendor/bin) ao PATH
ENV PATH="/opt/drupal/vendor/bin:${PATH}"


# ----------------------------------------------------
# 4. Ajusta Permissões e Diretórios
# ----------------------------------------------------


# Cria e ajusta permissões das pastas de arquivos (elas estão em web/sites/...)
RUN mkdir -p web/sites/default/files web/sites/default/private \
    && chown -R www-data:www-data web/sites/default/files web/sites/default/private \
    && find web -type d -exec chmod 755 {} \; \
    && find web -type f -exec chmod 644 {} \;

# Define o usuário www-data para rodar comandos futuros (como o Drush interativo)
USER www-data

EXPOSE 80

# Comando padrão da imagem base do Drupal
CMD ["apache2-foreground"]
