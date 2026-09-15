# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rmedeiro <rmedeiro@student.42lisboa.com    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/06/05 22:53:35 by rmedeiro          #+#    #+#              #
#    Updated: 2026/09/15 14:23:49 by rmedeiro         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rmedeiro <rmedeiro@student.42lisboa.com>    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#                                                                              #
# **************************************************************************** #

NAME = inception

COMPOSE = docker compose -f srcs/docker-compose.yml

all: mandatory

build:
	$(COMPOSE) build

mandatory:
	BONUS_MODE=0 $(COMPOSE) up -d --build mariadb wordpress nginx

bonus:
	BONUS_MODE=1 $(COMPOSE) up -d --build

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

logs:
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down

fclean:
	$(COMPOSE) down -v

re: fclean mandatory

.PHONY: all build mandatory bonus stop start logs clean fclean re
