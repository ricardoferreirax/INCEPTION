# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rmedeiro <rmedeiro@student.42lisboa.com    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/09/16 23:11:16 by rmedeiro          #+#    #+#              #
#    Updated: 2026/09/17 00:13:21 by rmedeiro         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

NAME = inception

COMPOSE = docker compose -f srcs/docker-compose.yml

DATA_DIR = /home/$(USER)/data
MDB_DIR = $(DATA_DIR)/mariadb
WP_DIR = $(DATA_DIR)/wordpress

MANDATORY = mariadb wordpress nginx

all: base

build:
	$(COMPOSE) build

base:
	mkdir -p $(MDB_DIR)
	mkdir -p $(WP_DIR)
	$(COMPOSE) up -d --build $(MANDATORY)

bonus:
	mkdir -p $(MDB_DIR)
	mkdir -p $(WP_DIR)
	$(COMPOSE) up -d --build

stop-base:
	$(COMPOSE) stop $(MANDATORY)

start-base:
	$(COMPOSE) start $(MANDATORY)

stop-bonus:
	$(COMPOSE) stop

start-bonus:
	$(COMPOSE) start

logs:
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down

fclean: clean
	$(COMPOSE) down -v
	sudo rm -rf $(DATA_DIR)

re: fclean base

rebonus: fclean bonus

.PHONY: all build base bonus stop-base start-base stop-bonus start-bonus logs clean fclean re
