# Lab 3. Desplegar App Contenerizada en un Clúster Swarm

En esta guía vamos a desplegar una Aplicación desarrollada con Nodejs que utiliza una base de datos
NoSQL MongoDB en un clúster Swarm. Para monitorizar los contenedores usaremos la aplicación contenerizada visualizer.


## Crear el clúster S
https://docs.docker.com/engine/swarm/swarm-tutorial/

Crear 3 máquinas virtuales, una de ellas la denominaremos: master y las otras dos: worker1 y worker2.

Instalamos docker en cada una de ellas. Aquí tienes un script para incluir como datos de usuario al crearla.

```
#!/bin/bash
# Install docker
apt-get update
apt-get install -y cloud-utils apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
apt-get update
apt-get install -y docker-ce
usermod -aG docker ubuntu
```

Añade las siguientes reglas de firewall:

```

TCP port 2376 for secure Docker client communication. 
TCP port 2377. This port is used for communication between the nodes of a Docker Swarm or cluster. 
TCP and UDP port 7946 for communication among nodes (container network discovery).
UDP port 4789 for overlay network traffic (container ingress networking).
TCP port 22 to SSH into our instances remotely
```

Iniciamos el Swarm en la máquina máster
```
$ docker swarm init

Swarm initialized: current node (sqab0b4s7an7rbnxfujwqzsjq) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-2-2755s1w5d5ssynkmlz1qvrorw6lox4p5f0ibjgp4mh1p038t6d-ax1xe0bdhal9pg8a8zbkvf736 10.132.0.10:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.

```

Unimos al Swarm los otros dos nodos como workers

```
$ docker swarm join --token SWMTKN-2-2755s1w5d5ssynkmlz1qvrorw6lox4p5f0ibjgp4mh1p038t6d-ax1xe0bdhal9pg8a8zbkvf736 10.132.0.10:2377

This node joined a swarm as a worker.

```

Ver el estado del Swarm:

```
$ docker node ls
```

## Construir la imagen de la aplicación a partir del Dockerfile

La aplicación y el resto de ficheros para esta guía están disponible en un repositorio Github.

Para clonarlo ejecuta el siguiente comando en la máquina master:


```
$ git clone https://github.com/MII-CC-2024/docker_lab3_docker-swarm.git
```


### Aplicación Nodejs

Para esta guía se ha creado una aplicación Node que permite guardar enlaces de interés, utilizando express como framework web y una base de datos MongoDB para almacenarlos.

El fichero principal index.js contiene:

```js
var express = require('express');
var app = express();

var bodyParser = require('body-parser');
app.use(bodyParser.json());
var urlencodedParser = bodyParser.urlencoded({ extended: false });

var mongoose = require('mongoose');
var urlmongo = 'mongodb://mongo/linkdb';
mongoose.connect(urlmongo, { useNewUrlParser: true }, function(err, dbmongo) {
     if (err) { 
        console.log("Error: " + err);
     } else {
        console.log("Conectado...");
     }
});

var linkSchema = mongoose.Schema({
    _id: mongoose.Schema.Types.ObjectId,
    url: String,
    description: String
});
var Link = mongoose.model('Link', linkSchema);

app.set('view engine', 'ejs');


app.get('/', function (req, res) {
    
     Link.find(function (err, links){
        if (err) return console.log(err);
        res.render('index.ejs', {'links': links});
    });
    

});

var router = express.Router();
app.use('/api', router);

router.get('/test', function (req, res) {
   res.send('Hello World');
});

var link_list = function (req, res) {
    Link.find(function (err, links){
        if(err) return res.send({message: 'Error en el servidor'});
        
        if(links){
            res.json({'links': links});
        }else{
            return res.status(404).send({
                message: 'No hay links'
            });
        }
    });
};
router.get('/list',link_list);

var link_create = function (req, res) {
    var l = new Link(
        {
           _id: new mongoose.Types.ObjectId(),
            url: req.body.url,
            description: req.body.description
        }
    );

    l.save(function (err) {
        if (err) {
            res.send('<p>ERROR: Link Not Created</p><a href="">Volver</a>');
        } else {
            res.send('Link Created successfully - <a href="/">Volver</a>'); 
            console.log('Link: ' + l.url + ' Created successfully');
        }
    });
};
router.post('/create', urlencodedParser, link_create);


var link_delete = function (req, res) {
    Link.findByIdAndRemove(req.params.id, function (err) {
        if (err) res.send('<p>ERROR: Link Not Deleted</p><a href="">Volver</a>');
        else {
            res.send('Deleted successfully! - <a href="/">Volver</a>');
            console.log('Link: ' + req.params.id + ' deleted successfully');
        }
    });
};
router.get('/delete/:id', link_delete);

var server = app.listen(8080, function () {
   var host = server.address().address;
   var port = server.address().port;

   console.log("Example app listening at http://%s:%s", host, port);
});
```

Los requisitos están indicados en el fichero package.json:

```json
{
  "name": "node-webapp",
  "version": "1.0.0",
  "description": "Web App con Node",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "repository": {
    "type": "git",
    "url": "git+https://github.com/jlalvarez/node-webapp.git"
  },
  "author": "J.L. Álvarez",
  "license": "ISC",
  "bugs": {
    "url": "https://github.com/jlalvarez/node-webapp/issues"
  },
  "homepage": "https://github.com/jlalvarez/node-webapp#readme",
  "dependencies": {
    "body-parser": "^1.18.3",
    "ejs": "^2.6.1",
    "express": "^4.16.4",
    "mongoose": "^5.5.3"
  }
}
```

Y, en la carpeta views, contamos con la vista views/index.ejs

```html
<!DOCTYPE html>
<html>
    <head>
        <title>Aplicación Enlaces de Interés</title>
        <meta charset="UTF8" />
    </head>
   <body>
       <h1>Enlaces de Interés</h1>

      <ul class="quotes">
        <% for(var i=0; i<links.length; i++) {%>
            <li class="quote">
                <a href='<%= links[i].url %>' ><%= links[i].description %></a> -
                [<a href='/api/delete/<%=links[i]._id%>'>Delete</a>]
            </li>
        <% } %>
      </ul>
      
       
      <hr />
      
      <h3>Puedes crear nuevos enlaces desde este formulario</h3>
      <form action = "/api/create" method = "POST">
         URL del Link: <input type = "url" name = "url" size = "40">  <br>
         _Description_: <input type = "text" name = "description">
         <input type = "submit" value = "Submit">
      </form>
      
   </body>
</html>
```

### Dockerfile

Además, se incluye el fichero Dockerfile para crear la imagen

```
FROM node:10

# Establecer Directorio de trabajo
WORKDIR /usr/src/app

# Copiar contenido de la Aplicación
COPY app/ ./

# Instalar dependencias
RUN npm install

# Exponer puerto 8080
EXPOSE 8080

# Ejecutar Aplicación
CMD ["node", "index.js"]
```

Ahora puedes crear la imagen con el comando: 

```
$ docker build -t <username>/<dockerimage> .
```

Donde <username> debe ser sustituido por tu usuario en Docker Hub y <dockerimage> por el nombre
que se dará a la imagen. Por ejemplo, jluisalvarez/node-webapp

y subir la imagen al Docker Hub. Para ello, identificate y luego sube la imagen.

```js
$ docker login
```

```js
$ docker push <username>/<dockerimage>
```


## Docker Compose

El fichero doker-compose.yml tiene definidos 3 servicios, una red para conectarlos y un volumen para persistir los datos
de MongoDB.

```js
version: "3.9"
services:
  web:
    image: <username>/<dockerimage>
    depends_on:
      - mongo
    deploy:
      replicas: 2
      restart_policy:
        condition: on-failure
      resources:
        limits:
          cpus: "0.1"
          memory: 50M
    ports:
      - "80:8080"
    networks:
      - webnet

  visualizer:
    image: dockersamples/visualizer:stable
    ports:
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    deploy:
      placement:
        constraints: [node.role == manager]
    networks:
      - webnet

  mongo:
    image: mongo
    volumes:
      - db-data:/data/db
    deploy:
      placement:
        constraints: [node.role == manager]
    networks:
      - webnet

volumes:
  db-data:

networks:
  webnet:
```


## Desplegar servicios:

Podrás desplegar los servicios ejecutando el siguiente comando:

```shell
$ docker stack deploy -c docker-compose.yml webapp
```

Puedes acceder al vizualizer con: http://<ip_master>:8080
Puedes acceder a la aplicación con: http://<ip_master>

## Mostrar listado de servicios y contenedores

```shell
$ docker service ls
```

```shell
$ docker stack ps webapp
```

## Escalar servicios

docker service scale webapp_web=4


## Eliminar servicios

```shell
$ docker stack rm webapp
```

## Comandos Swarm

* swarm init
* swarm join
* service create
* service inspect
* service ls
* service rm
* service scale
* service ps
* service update





