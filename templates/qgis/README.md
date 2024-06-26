# QGIS Server

Prepare QGIS projects offline on your desktop, and upload them to QGIS Server,
to have the data served as WMS (and more).

## Setup

1. Use this template to create a `qgis` component in your application.
1. Also add a [dynamic](../serve/dynamic) component to serve any
   static files from `$DOCKER_BINDS_DIR/fileport/$DOCKER_USER`.
1. A [proxy](../proxy) component is needed as well, but you probably
   already have it.

## Prepare project in QGIS

1. Create a project in QGIS, and edit the project's properties to:
   1. Under `CRS`, define the CRS to use.
   1. Under `General`, make sure the `Save paths` entry is set to `Relative`.
1. Create a new, empty, directory, and save the project file there _**as a
   `.qgs` file**_ (not `.qgz`).
1. Add data layers to the project.
   1. For file based layers (Shapefile, raster, etc.):
      1. First copy the file(s) to the _**same directory as the project file**_.
      1. Then add a layer from that file.
1. When done adding layers, zoom to the extent of the widest layer.
1. Edit the project's properties; go to the `QGIS Server` tab. Under WMS
   capabilities,
   1. Check `Advertised extent`, and click `Use Current Map Canvas Extent`.
   1. Check `CRS restrictions`, and click `Used`. Also add `EPSG:3857`, and
      `EPSG:4326`.
1. Save the project.
1. Upload the project file to QGIS Server:
   1. In your browser, go to
      [https://$PROXY_HOST[:$PROXY_PORT][/$DOCKER_USER]/qgisupload/index.php](),
      e.g. https://localhost:7443/qgisupload/index.php.
   1. Using the `Select Files` button, browse to the directory where your QGIS
      project file (`.qgs`) was saved, and select _**all files in that
      directory**_.
   1. Now click the Upload button.
   1. When the upload completes, you'll see your files listed in a newly created
      directory for your project on the server.

## Access project on QGIS Server

Each uploaded project is available as an [OGC WMS
service](https://docs.qgis.org/3.22/en/docs/server_manual/services/wms.html) on
QGIS Server through
[https://$PROXY_HOST[:$PROXY_PORT][/$DOCKER_USER]/qgis/project/$PROJECT_NAME?service=WMS&request=GetCapabilities](),
e.g.
https://localhost:7443/qgis/project/65521-1?service=WMS&request=GetCapabilities.

Note that the [MAP
parameter](https://docs.qgis.org/3.22/en/docs/server_manual/services/basics.html#services-basics-map)
should not be given; it's set automatically, based on the `$PROJECT_NAME` part of
the URL.

## Authorisation

The docker4gis proxy automatically provides three paths for QGIS Server:

- `qgis=http://$DOCKER_USER-qgis/qgis/`
- `qgisupload=http://$DOCKER_USER-qgis/upload/`
- `qgisfiles=http://$DOCKER_USER-qgis-dynamic/qgisfiles/`

And then it works. But. Everything is accessible to everyone. You shouldn't want
that.

### AUTH_PATH

If you haven't already, set a URL value for the
[AUTH_PATH](https://github.com/merkatorgis/docker4gis/blob/master/docs/proxy.md#authorized-destinations)
variable, and serve a handler there, that tests who is logged in, and if the
current request is allowed for that user.

### authorise,

In your proxy component's `conf/args` file, add the following [additional
destinations](https://github.com/merkatorgis/docker4gis/blob/master/docs/proxy.md#additional-destinations):

```
qgis=authorise,http://$DOCKER_USER-qgis/qgis/
qgisupload=authorise,http://$DOCKER_USER-qgis/upload/
qgisfiles=authorise,http://$DOCKER_USER-qgis-dynamic/qgisfiles/
```

### Check

In your `AUTH_PATH` endpoint, determine who can do what, based on the logged-in
user's roles, and the `path` of the incoming request.

For instance, you could:

- Limit access to paths starting with `/qgis` to users that are logged into your
  application.
  - Limit access to specific project paths and/or layers parameter values,
    based on specific roles that the user should have.
- Limit access to paths starting with `/qgisupload` and `/qgisfiles` (the
  latter for the directory listing in the `Upload` page) to logged-in users that
  are an administrator.
