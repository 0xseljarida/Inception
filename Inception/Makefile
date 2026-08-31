NAME		= inception

COMPOSE		= docker compose -f srcs/docker-compose.yml
VOLUMES		= /home/login/data/mariadb /home/login/data/wordpress

DOMAIN		= login.42.fr
RESUME		= login.resume.42.fr
HOSTS_LINE	= 127.0.0.1 $(DOMAIN) $(RESUME)

all: up

$(VOLUMES):
	mkdir -p $@

up: $(VOLUMES)
	$(COMPOSE) up -d --build

hosts:
	@grep -qF "$(RESUME)" /etc/hosts || echo "$(HOSTS_LINE)" | sudo tee -a /etc/hosts > /dev/null

re: fclean all

clean:
	$(COMPOSE) down --rmi local

fclean: clean
	$(COMPOSE) down -v
	sudo rm -rf $(VOLUMES)

.PHONY: all up hosts re clean fclean
