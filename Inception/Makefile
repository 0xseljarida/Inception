NAME		= inception
LOGIN		= sel-jari

COMPOSE		= docker compose -f srcs/docker-compose.yml
DATA_DIR	= /home/$(LOGIN)/data
VOLUMES		= $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

DOMAIN		= $(LOGIN).42.fr
RESUME		= $(LOGIN).resume.42.fr
HOSTS_LINE	= 127.0.0.1 $(DOMAIN) $(RESUME)

all: up

$(VOLUMES):
	mkdir -p $@

up: $(VOLUMES)
	$(COMPOSE) up -d --build

# Maps the project domains to the loopback address. Needs sudo, so it is kept
# out of 'up'. The guard makes it safe to run any number of times.
hosts:
	@grep -qF "$(RESUME)" /etc/hosts \
		&& echo "/etc/hosts already maps $(DOMAIN) and $(RESUME)" \
		|| echo "$(HOSTS_LINE)" | sudo tee -a /etc/hosts > /dev/null

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

.PHONY: all up hosts down stop start re logs ps clean fclean
