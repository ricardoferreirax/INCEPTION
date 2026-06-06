# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rmedeiro <rmedeiro@student.42lisboa.com    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/06/05 22:53:35 by rmedeiro          #+#    #+#              #
#    Updated: 2026/06/06 20:47:30 by rmedeiro         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

NAME = inception

COMPOSE	= docker compose -f srcs/docker-compose.yml

DATA_DIR = /home/$(USER)/data
MDB_DIR	= $(DATA_DIR)/mariadb
WP_DIR = $(DATA_DIR)/wordpress

all: up

dirs:
	mkdir -p $(MDB_DIR)
	mkdir -p $(WP_DIR)

build:
	$(COMPOSE) build

no-cache:
	$(COMPOSE) build --no-cache

up: dirs
	$(COMPOSE) up -d --build

db: dirs
	$(COMPOSE) up -d --build mariadb

wp: dirs
	$(COMPOSE) up -d --build wordpress

nginx: dirs
	$(COMPOSE) up -d --build nginx

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

clean:
	$(COMPOSE) down -v

fclean: clean
	sudo rm -rf $(MDB_DIR)
	sudo rm -rf $(WP_DIR)

re: fclean up

.PHONY: all dirs build no-cache up db wp nginxdown stop start clean fclean re