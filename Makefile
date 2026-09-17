# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rmedeiro <rmedeiro@student.42lisboa.com    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/09/16 23:11:16 by rmedeiro          #+#    #+#              #
#    Updated: 2026/09/17 21:54:50 by rmedeiro         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

NAME = inception
COMPOSE = docker compose -f srcs/docker-compose.yml
DATA_DIR = /home/$(USER)/data
MDB_DIR = $(DATA_DIR)/mariadb
WP_DIR = $(DATA_DIR)/wordpress

all: up

build:
	$(COMPOSE) build

up:
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

re: fclean all

.PHONY: all build up stop start logs clean fclean re
