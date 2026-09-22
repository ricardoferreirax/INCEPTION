## Eval questions 

### 1) How Docker and Docker Compose works?

Docker: é uma plataforma que corresponde a um conjunto de ferramentas que permitem criar, executar e gerir containers.

Docker Compose: é uma ferramenta usada para definir e gerir vários containers em conjunto. Lê o ficheiro docker-compose.yml, onde declaramos os serviços, networks, volumes, portas, secrets e dependências, e comunica com o Docker Engine para criar toda essa infraestrutura.

Resposta: Docker cria e gere os containers; Docker Compose define e coordena vários containers e os recursos necessários para funcionarem em conjunto.

### 2) The difference between a Docker image used with docker compose and without docker compose

Não existe diferença na Docker image em si.
Uma image criada com docker build e uma image criada através de docker compose build, são ambas Docker images normais.
A diferença está na forma como são construídas, configuradas e utilizadas:

Sem Docker Compose: tens de usar manualmente comandos como docker build e docker run, indicando networks, volumes, portas, environment variables, secrets, etc.
Com Docker Compose: essas configurações ficam declaradas no docker-compose.yml, e o Compose comunica com o Docker Engine para criar e configurar os containers.
Resposta curta para avaliação

Não existe uma image especial do Docker Compose. O Compose utiliza Docker images normais. A diferença é que o Docker Compose automatiza e centraliza num ficheiro YAML a construção das images e a configuração dos containers, networks, volumes, portas, secrets e dependências.

### 3) The benefit of Docker compared to VMs

O Docker é mais leve e rápido porque os containers partilham o kernel do sistema operativo do host, enquanto uma VM virtualiza uma máquina completa e normalmente executa o seu próprio sistema operativo e kernel.

Por isso, os containers normalmente:

iniciam mais rapidamente;
consomem menos RAM e armazenamento;
são mais fáceis de criar e destruir;
permitem executar mais serviços com os mesmos recursos.
Resposta curta para avaliação

A principal vantagem do Docker é ser mais leve que uma VM. Uma VM virtualiza uma máquina completa e tem o seu próprio sistema operativo e kernel, enquanto os containers partilham o kernel do host e isolam principalmente os processos e as suas dependências. Por isso, containers são geralmente mais rápidos de iniciar e consomem menos recursos.

Mas atenção: Docker não substitui completamente VMs. As VMs oferecem isolamento ao nível da máquina, enquanto os containers oferecem isolamento ao nível dos processos. No Inception usamos os dois: a VM isola o projeto da máquina física e Docker isola os serviços dentro da VM.

---------------------------------------------------------------------------------------------------------------------------------------





## 1) O que é o Docker?

Docker é uma plataforma que corresponde a um conjunto de ferramentas que permitem criar, 
executar e gerir containers.

"Docker" não é propriamente um serviço, Docker é o nome da plataforma como um todo.
No Linux, uma das peças principais do Docker, o Docker daemon, corre efetivamente como um serviço do sistema.
Podemos visualizar assim:

                    DOCKER
                       │
        ┌──────────────┼───────────────┐
        │              │               │
        ▼              ▼               ▼
   Docker CLI     Docker Daemon    Docker Objects
   (docker)        (dockerd)        │
                                   ├── Images
                                   ├── Containers
                                   ├── Networks
                                   └── Volumes

Portanto, quando falamos em "Docker", estamos normalmente a falar do conjunto inteiro, não apenas de um único 
serviço.

### 1.1) Docker Engine

O Docker Engine é a tecnologia principal que permite criar e executar containers. De forma simplificada, é 
composto principalmente por:

Docker Engine
│
├── Docker CLI
│
└── Docker Daemon

#### 1.2) Docker CLI

Quando escreves docker ps ou docker build ou mesmo docker run nginx, estás a utilizar o Docker CLI (Command Line 
Interface). É basicamente o comando docker. O CLI recebe aquilo que escreveste e comunica com o Docker daemon.

Por exemplo:

 Eu
 │
 │ docker ps
 ▼
Docker CLI
 │
 │ request
 ▼
Docker Daemon

O CLI, por si só, não é quem executa os containers. É principalmente a interface através da qual damos instruções 
ao Docker Engine.

#### 1.3) Docker Daemon

Aqui chegamos à parte que realmente é um serviço. O Docker daemon, ou dockerd, é um processo que corre em background 
e é responsável por gerir os objetos Docker, como por exemplo:

- containers;
- images;
- networks;
- volumes.

Podemos pensar assim:

              Docker Daemon
                  dockerd
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
    Containers    Images     Networks
                                │
                              Volumes


Quando escreves docker ps, não é simplesmente o comando docker que vai sozinho procurar os containers. Simplificando:

								User
								 │
								 │ docker ps
								 ▼
						    Docker CLI
								 │
								 │ Docker API
								 ▼
						    Docker Daemon
								 │
								 │
								 ▼
							obtém informação
							dos containers
								 │
								 ▼
							 Docker CLI
								 │
								 ▼
							  Terminal

Ou seja:

- escreves docker ps;
- o Docker CLI interpreta o comando;
- comunica com o Docker daemon;
- o daemon obtém a informação;
- a resposta é devolvida;
- o CLI apresenta-a no terminal.

### 2) O que é realmente um container no Linux?

No Linux, um container é essencialmente um conjunto de processos isolados.

Assim, o processo pode sentir que está num ambiente próprio, apesar de continuar a utilizar o mesmo kernel Linux.
Todos os processos dentro dos containers usam o mesmo kernel, mas estão isolados uns dos outros.

Um container é um conjunto de processos do Linux aos quais o kernel aplica mecanismos de isolamento e controlo.
Ou seja, quando tens:

- Container NGINX
- Container WordPress
- Container MariaDB

não existem três kernels Linux diferentes. Tens algo mais próximo disto:

                 Linux Kernel
                      │
          ┌───────────┼───────────┐
          │           │           │
          ▼           ▼           ▼
       nginx       php-fpm      mariadbd
       process      process       process
          │           │           │
       isolated    isolated    isolated
        view         view         view

Todos continuam a ser processos executados pelo mesmo kernel Linux.
A "magia" está no facto de o kernel conseguir controlar o que cada grupo de processos consegue ver, utilizar e aceder.

Três conceitos são especialmente importantes:

Namespaces  → O que o processo consegue VER?
Cgroups     → Quanto é que o processo pode USAR?
Filesystem  → Que ficheiros é que o processo VÊ?

Essa é uma excelente forma de começar a distinguir os três.

#### 2.1) Namespaces — isolamento

Os Linux namespaces são uma funcionalidade do kernel que permite dar a determinados processos uma visão isolada 
de recursos do sistema. Sem namespaces, os processos normalmente partilham a visão global do sistema.
Com namespaces, podemos colocar determinados processos numa visão isolada.

Do ponto de vista do container, parece que existe essencialmente o seu próprio conjunto de processos.
Mas o kernel sabe perfeitamente que o processo pertence ao sistema real.
O container não tem um kernel próprio. O container pode parecer ter:

- seus processos
- sua network
- seu hostname
- seus mounts
- seu filesystem

mas não tem um kernel Linux independente. É o kernel do host que cria essas diferentes visões.
Podes imaginar o kernel como tendo a realidade completa:

                    KERNEL
                       │
       ┌───────────────┼───────────────┐
       │               │               │
       ▼               ▼               ▼
 Namespace A      Namespace B      Namespace C
       │               │               │
     nginx           php-fpm         mariadbd

Cada processo observa apenas a parte do sistema que o namespace lhe permite observar.

--------------------------------------------------------------------------------------------------------

##### 2.1.1) PID Namespace — isolamento de processos

Um PID namespace permite que um grupo de processos tenha a sua própria árvore de PIDs.
Assim, o mesmo processo pode ter um PID dentro do container e outro PID visto pelo host.

Por exemplo:

     HOST                      CONTAINER

PID 7421  php-fpm   <---->   PID 1 php-fpm

Dentro do container, pode parecer que php-fpm é PID 1, mas no host, o kernel pode conhecer esse 
processo como PID 7421. Não existem dois processos. É o mesmo processo visto através de namespaces 
diferentes.

No WordPress tens exec php-fpm8.2 -F. O exec substitui o processo do shell pelo PHP-FPM.
Assim, PHP-FPM passa a ser o processo principal do container:

PID 1
└── php-fpm

É também por isso que o teu healthcheck consegue olhar para /proc/1/cmdline e verificar se o processo 
principal é PHP-FPM.

##### 2.1.2) Network Namespace — isolamento de rede

Um network namespace fornece uma visão isolada dos recursos de networking. 
Um container pode ter as suas próprias:

- interfaces de rede;
- endereços IP;
- portas;
- regras de networking.

Por isso dois containers podem, por exemplo, ter aplicações a escutar na mesma porta interna sem 
necessariamente existir conflito.

Imagina:

Container A
IP: 172.x.x.2
Port: 9000

Container B
IP: 172.x.x.3
Port: 9000

Isso é possível porque os containers têm contextos de rede separados.

O WordPress tem a sua interface virtual ligada à Docker bridge. MariaDB tem outra. NGINX também tem outra.
Docker configura a conectividade entre esses network namespaces.

##### 2.1.3) Mount Namespace — isolamento de mounts

Um mount namespace controla a visão que um processo tem dos mounts/filesystems.
Isto ajuda a explicar porque dentro de um container podes ver:

/
├── bin
├── etc
├── usr
├── var
└── ...

e parece que tens um sistema de ficheiros próprio. Por exemplo, dentro de MariaDB, /var/lib/mysql pode 
estar ligado a storage persistente. Enquanto no WordPress, /var/www/html está ligado a outro storage.
Cada container pode ter uma visão diferente dos mounts:

MariaDB namespace

/
├── etc
├── usr
└── var
    └── lib
        └── mysql  ← volume

WordPress namespace

/
├── etc
├── usr
└── var
    └── www
        └── html   ← volume

O mount namespace ajuda a fazer com que cada processo veja a sua própria organização de mounts.

------------------------------------------------------------------------------------------------------------

#### 2.2) Cgroups — controlo de recursos

Namespaces respondem principalmente: O que posso ver?

Cgroups respondem principalmente: Que recursos posso usar e como são controlados?

cgroups significa control groups.

São uma funcionalidade do kernel Linux para organizar processos em grupos e controlar recursos.

Por exemplo:

Linux Kernel
│
├── Group A
│   └── nginx
│
├── Group B
│   └── php-fpm
│
└── Group C
    └── mariadbd

O kernel consegue aplicar políticas de recursos aos diferentes grupos. Dependendo da configuração 
e versão de cgroups, isto envolve recursos como:

- CPU;
- memória;
- número de processos;

##### 2.2.1) Porque precisamos de cgroups?

Imagina que tens:

- NGINX
- WordPress
- MariaDB

e WordPress entra num comportamento anormal e começa a consumir recursos excessivamente.
Sem mecanismos de controlo, um processo pode competir agressivamente pelos recursos disponíveis e afetar 
os restantes serviços.

Conceptualmente:

Total RAM
████████████████████

WordPress
███████████████████

Everything else
█

Com limites configurados através dos mecanismos apropriados de cgroups, podes restringir recursos.
Por exemplo, conceptualmente:

WordPress
Maximum memory: 512 MB

Então:

               Host Resources
                    │
        ┌───────────┼───────────┐
        │           │           │
      NGINX      WordPress    MariaDB
        │           │           │
     cgroup       cgroup       cgroup

O kernel consegue contabilizar e aplicar os limites/políticas definidos.

Existir um cgroup não significa necessariamente que definiste um limite de 512 MB ou 1 CPU.
Se não configurares limites específicos, o container pode continuar a competir por muitos dos recursos disponíveis.
Ou seja, cgroups fornecem o mecanismo; as políticas/limites concretos dependem da configuração.

##### Qual é a diferença entre namespaces e cgroups?

Resposta: Namespaces são principalmente responsáveis pelo isolamento, ou seja, controlam a visão que os 
          processos têm dos recursos do sistema. Cgroups são responsáveis pelo agrupamento, contabilização 
		  e controlo de recursos consumidos pelos processos, como CPU e memória.

---------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------

#### Juntando tudo: como é criado o isolamento?

Agora imagina o teu container WordPress.

Tens:

                WORDPRESS CONTAINER
                        │
        ┌───────────────┼────────────────┐
        │               │                │
        ▼               ▼                ▼
   Namespaces        Cgroups         Filesystem
        │               │                │
        ▼               ▼                ▼
 isolated view     resource control    isolated root
        │                                │
        ├─ PID                            └─ layers
        ├─ network                             +
        ├─ mounts                            volumes
        ├─ hostname
        └─ ...

O PHP-FPM continua a ser um processo Linux, mas os Namespaces fazem com que tenha uma visão isolada 
do sistema.
Cgroups permitem ao kernel organizar e limitar os recursos usados por esse processo/grupo.
Filesystem/mounts fazem com que veja o ambiente de ficheiros construído a partir da image, juntamente 
com os volumes que lhe foram montados.

Portanto, o processo sente que está num ambiente independente:

"I have my own processes"
"I have my own network"
"I have my own hostname"
"I have my own filesystem"

Mas na realidade:

                    SAME LINUX KERNEL
                           │
          ┌────────────────┼────────────────┐
          │                │                │
        nginx           php-fpm          mariadbd
          │                │                │
      container        container        container
       isolation        isolation        isolation

#### "Então o que cria um container?"

RESPOSTA: Um container não é uma máquina virtual nem tem necessariamente um kernel próprio. No Linux, é 
um conjunto de processos normais isolados através de funcionalidades do kernel. Namespaces isolam a visão 
que esses processos têm de recursos como PIDs, networking e mounts. Cgroups permitem agrupar e controlar 
recursos como CPU e memória. Além disso, Docker fornece ao container um filesystem construído a partir 
dos layers da image, com uma writable layer própria, e podemos montar volumes para dados que precisam de persistir.


## Porque precisamos do Docker? O que acrescenta e o que facilita?

O Docker permite criar, executar e gerir aplicações dentro de ambientes isolados (containers).
No Inception, poderíamos teoricamente instalar o NGINX, MariaDB, WordPress, Redis, etc. diretamente na 
máquina virtual. O problema é que todos esses serviços passariam a partilhar diretamente o mesmo sistema: 
pacotes, configurações, processos e filesystem.
Com Docker, conseguimos separar a infraestrutura em vários ambientes independentes:

VM
│
└── Docker
    │
    ├── Container NGINX
    ├── Container WordPress
    ├── Container MariaDB
    ├── Container Redis
    ├── Container Adminer
    ├── Container FTP
    ├── Container Static
    └── Container Portainer

Cada container tem o seu próprio filesystem, processos, configuração e dependências, embora os containers 
partilhem o kernel da máquina host, que neste caso é a nossa VM.

RESPOSTA FINAL: Usamos O Docker para isolar cada serviço da infraestrutura num container independente e tornar o ambiente 
reproduzível e fácil de gerir. Cada serviço tem as suas próprias dependências e configuração, em vez de instalarmos tudo 
diretamente na VM. Os containers são leves porque partilham o kernel do host e podem ser facilmente criados, removidos e 
reconstruídos a partir das imagens. Docker também nos fornece networking entre containers e mecanismos de volumes para 
separar os dados persistentes do ciclo de vida dos containers. No Inception, isto permite ter NGINX, WordPress, MariaDB, 
Redis e os restantes serviços separados, mas a comunicar entre si através de uma Docker network. Depois usamos Docker 
Compose para definir e gerir toda essa infraestrutura em conjunto.

