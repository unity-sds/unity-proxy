# Developing for the proxy

## Build the docker container locally

```
docker build -t unity-proxy-dev -f Dockerfile.developer .
```

We need a "special" proxy without the management console additions present. Ideally the proxy would not be tied to the management console, but here we are.

## Add files to the sites-enabled folder

The proxy works by looking at "conf" files in the "sites-enabled" directory within apache (within the container, this is /etc/apache2/sites-enabled). To facillitate dynamic additions, the unity-proxy code allows for individualized configurations to be added. This is done in two areas:

1. Add a `*.conf` file to the sites-enabled directory. This is where you want to put all your proxy informations. DO NOT INCLUDE `<VirtualHost>` tags within this.
2. Add an 'Include' to the `sites-enabled/main.conf` file to include this new entry. Note how the `main.conf` file already defines the <VirtualHost> section? This is why it's not included above.

**Note:** whatever path you end up proxying TO your service will be visible to the user. So, for example, we want something like `jupyter` not `mikes-dev-jupyter` and it should be consistent across ALL venues. Care shoud be taken to make sure you're not conflicting with another service.


## Run the container
```
docker run --name apache2 --rm -p 8080:8080 -v $PWD/sites-enabled:/etc/apache2/sites-enabled 425ffb0c6c2d
```

This will mount the local sites-enabled directory over the default directory so that one can develop quickly. Simply keep tweaking the *.conf file you created until your proxy is working.

You can now navigate to `localhost:8080/<proxyPath>` to test out your proxy params.

When ready, kill your container

```
docker kill apache2
```

## Finalizing

When ready, add your config to the deployed unity-proxy instance, you have all the information needed to follow the instructions in the ../README.md file.

The `filename` should be whatever you named your `*.conf` file WITHOUT the `.conf` suffix. The `template` value should be the contents of your `*.conf` file. 

Add these to your terraform script to update the venue proxy with your information. 

