# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rmedeiro <rmedeiro@student.42lisboa.com    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/06/05 22:53:35 by rmedeiro          #+#    #+#              #
#    Updated: 2026/06/21 23:10:01 by rmedeiro         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

NAME = inception

COMPOSE	= docker compose -f srcs/docker-compose.yml

DATA_DIR = /home/$(USER)/data
MDB_DIR	= $(DATA_DIR)/mariadb
WP_DIR = $(DATA_DIR)/wordpress

all: up

build:
	$(COMPOSE) build

no-cache:
	$(COMPOSE) build --no-cache

up: 
	mkdir -p $(MDB_DIR)
	mkdir -p $(WP_DIR)
	$(COMPOSE) up -d --build

db: 
	mkdir -p $(MDB_DIR)
	mkdir -p $(WP_DIR)
	$(COMPOSE) up -d --build mariadb

ftp:
	mkdir -p $(MDB_DIR)
	mkdir -p $(WP_DIR)
	$(COMPOSE) up -d --build ftp

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

logs:
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down -v

fclean: clean
	sudo rm -rf $(DATA_DIR)

re: fclean up

.PHONY: all dirs build no-cache up db down stop start clean fclean re