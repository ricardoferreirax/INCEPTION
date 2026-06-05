# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rmedeiro <rmedeiro@student.42lisboa.com    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/06/05 22:53:35 by rmedeiro          #+#    #+#              #
#    Updated: 2026/06/05 22:53:55 by rmedeiro         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

NAME = inception

COMPOSE	= docker compose -f srcs/docker-compose.yml

DATA_DIR = /home/rmedeiro/data
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

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

restart:
	$(COMPOSE) restart

mysql-root:
	docker exec -it mariadb mariadb -u root -p

clean:
	$(COMPOSE) down -v

fclean: clean
	sudo rm -rf $(MDB_DIR)
	sudo rm -rf $(WP_DIR)

re: fclean up

.PHONY: all dirs build no-cache up down stop start restart mysql-root clean fclean re