NAME		= inception
LOGIN		= sel-jari

COMPOSE		= docker compose -f srcs/docker-compose.yml
DATA_DIR	= /home/$(LOGIN)/data
VOLUMES		= $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

all: up

$(VOLUMES):
	mkdir -p $@

up: $(VOLUMES)
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

re: down up

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

clean: down
	$(COMPOSE) down --rmi local

fclean: clean
	$(COMPOSE) down -v
	sudo rm -rf $(VOLUMES)

.PHONY: all up down stop start re logs ps clean fclean
