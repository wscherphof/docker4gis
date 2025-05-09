<html>

<head>
  <style>
    body {
      overflow: hidden;
      margin: 1em;
    }

    h1 {
      height: 30px;
      margin: 0;
    }

    #box {
      display: flex;
      margin-top: 1em;
      height: calc(100% - 30px - 1em);
    }

    nav {
      flex-grow: 1;
      padding-left: 1em;
    }

    label>input {
      width: 100%;
      max-width: 20em;
      margin-top: .25em;
    }

    #loading {
      background-color: rgb(0, 0, 0, 0.2);
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
    }

    #loading img {
      position: absolute;
      width: 58px;
      height: 58px;
      top: calc(50% - 29px);
      left: calc(50% - 29px);
    }
  </style>
</head>

<?php $project = isset($_REQUEST['project']) ? $_REQUEST['project'] : ''; ?>

<body>
  <div id="loading" hidden>
    <!-- https://github.com/SamHerbert/SVG-Loaders -->
    <img src="spinning-circles.svg">
  </div>

  <h1>Manage files on QGIS Server</h1>

  <div id="box">

    <div>

      <div>
        <form id="form" enctype="multipart/form-data" action="upload.php" method="post">
          <p>
            <label>
              Select file *<br />
              <input type="file" name="file[]" id="file" required multiple />
            </label>
          </p>
        </form>

        <!-- The proxy will not forward the multipart/form-data request body to
        the authorisation endpoint; include the project value as a query
        parameter (using the submit event listener below). -->
        <p>
          <label>
            Project (if not .qgs)<br />
            <input type="text" name="project" id="project" value="<?= $project ?>" />
          </label>
        </p>

        <p>
          <input type="submit" form="form" name="upload" id="upload" value="Upload" />
        </p>

        <p id="error" style="color: red;" hidden>
          Please use .qgs project file type<br />
          instead of .qgz.
        </p>

        <script>
          file.addEventListener('change', () => {
            function ext(ext) {
              return Array.from(file.files).some(
                ({
                  name
                }) => name.toLowerCase().endsWith('.' + ext));
            }

            upload.disabled = ext('qgz');
            error.hidden = !upload.disabled;

            project.disabled = ext('qgs');
            project.value = project.disabled ? '' : project.value;
          });
          form.addEventListener('submit', () => {
            loading.hidden = false;
            if (project.value) {
              form.action += `?project=${project.value}`;
            }
          });
        </script>
      </div>

      <hr />

      <div>
        <form id="formDelete" enctype="multipart/form-data" action="delete.php" method="post">
          <p>
            <label>
              Paste file/directory url *<br />
              <input type="text" name="path" id="path" required />
            </label>
          </p>
        </form>

        <p>
          <input type="submit" form="formDelete" name="delete" id="delete" value="Delete" />
        </p>
      </div>

      <hr />

    </div>

    <nav>
      <iframe id="iframe" width="100%" height="100%" src="../qgisfiles/<?= $project ?>">
      </iframe>
    </nav>

  </div>

</body>

</html>