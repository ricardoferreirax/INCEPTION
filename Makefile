# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rmedeiro <rmedeiro@student.42lisboa.com    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/06/05 22:53:35 by rmedeiro          #+#    #+#              #
#    Updated: 2026/09/14 10:23:15 by rmedeiro         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

NAME = inception

COMPOSE = docker compose -f srcs/docker-compose.yml

DATA_DIR = /home/$(USER)/data
MDB_DIR = $(DATA_DIR)/mariadb
WP_DIR = $(DATA_DIR)/wordpress

all: mandatory

build:
	$(COMPOSE) build

mandatory:
	mkdir -p $(MDB_DIR)
	mkdir -p $(WP_DIR)
	$(COMPOSE) up -d --build mariadb wordpress nginx

bonus:
	mkdir -p $(MDB_DIR)
	mkdir -p $(WP_DIR)
	$(COMPOSE) up -d --build

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

logs:
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down

fclean: clean
	$(COMPOSE) down -v
	sudo rm -rf $(DATA_DIR)

re: fclean mandatory

.PHONY: all build mandatory bonus stop start logs clean fclean re