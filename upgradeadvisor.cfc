component output="false" {

  // TODO: DRY

  public any function init() {
    this.version = "2.x";
    return this;
  }

  /**
   * This plugin version number
   */
  public string function pluginVersion() {
    return "0.4.0";
  }

  /**
   * The main entry function that compiles the check results
   */
  public array function main() {
    return [
      adviseOfInitRename(),
      adviseOfServerVersion(),
      adviseOfRoutes(),
      adviseOfCSRF(),
      adviseOfRedundantFiles(),
      adviseOfDBMigrate(),
      adviseOfGlobalFunctions(),
      adviseOfTestMappings(),
      adviseOfConfigSettings(),
      adviseOfAppMapping(),
      adviseOfRemovedViewFunctions(),
      adviseOfUpdateProperties(),
      adviseOfUrlRewriting()
    ];
  }

  /**
   * Checks if the global functions file is in the correct location
   */
  public struct function adviseOfGlobalFunctions() {
    local.rv = {
      name="Global Functions",
      success=true,
      href="",
      messages=[]
    };
    local.oldGlobalHelpersPath = ExpandPath("/events/functions.cfm");
    local.newGlobalHelpersPath = ExpandPath("/global/functions.cfm");

    if (FileExists(local.oldGlobalHelpersPath)) {
      local.rv.success = false;
      ArrayAppend(local.rv.messages, {
        message="Move <code>#_pathFormat(local.oldGlobalHelpersPath)#</code> to <code>#_pathFormat(local.newGlobalHelpersPath)#</code>"
      });
      return local.rv;
    }

    return local.rv;
  }

  /**
   * Checks for the coldroute plugin and if coldroute style routes are in use
   */
  public struct function adviseOfRoutes() {
    local.rv = {
      name="Routes",
      success=true,
      href="",
      messages=[]
    };
    local.routesFileContent = FileRead(ExpandPath("/config/routes.cfm"));
    local.pluginDirectoryPath = ExpandPath("/plugins/coldroute");

    if (local.routesFileContent contains "addRoute" && local.routesFileContent does not contain "drawRoutes") {
      local.rv.success = false;
      ArrayAppend(local.rv.messages, {
        message="The <code>addRoute</code> function has been removed from Wheels 2.x. Use the new <code>drawRoutes</code> function/s"
      });
    }

    if (DirectoryExists(local.pluginDirectoryPath)) {
      local.rv.success = false;
      ArrayAppend(local.rv.messages, {
        message="The coldroute plugin is now part of the Wheels 2.x core. It can be removed."
      });
    }

    if (!local.rv.success) {
      local.rv.href = "http://docs.cfwheels.org/v2.x/docs/routing";
    }

    return local.rv;
  }

  /**
   * Checks for the bdmigrate plugin and migrations exten the correct component
   */
  public struct function adviseOfDBMigrate() {
    local.rv = {
      name="Database Migrations",
      success=true,
      href="",
      messages=[]
    };
    local.pluginDirectoryPath = ExpandPath("/plugins/dbmigrate");
    local.migrationsPath = ExpandPath("/db/migrate");
    local.mapping = "wheels.dbmigrate.Migration";

    if (DirectoryExists(local.pluginDirectoryPath)) {
      local.rv.success = false;
      ArrayAppend(local.rv.messages, {
        message="The dbmigrate plugin is now part of the Wheels 2.x core. It can be removed."
      });
    }

    // check migration inheritance
    if (DirectoryExists(local.migrationsPath)) {
      local.allFiles = DirectoryList(local.migrationsPath, false, "name", "*.cfc");

      local.files = ArrayFilter(local.allFiles, function(i) {
        local.cfc = GetComponentMetaData("db.migrate.#ListFirst(i, ".")#");
        return local.cfc.extends.fullname neq "wheels.dbmigrate.Migration";
      });
      if (ArrayLen(local.files)) {
        local.rv.success = false;
        ArrayAppend(local.rv.messages, {
          message="You have #ArrayLen(local.files)# migrations that must extend <code>#local.mapping#</code>."
        });
      }
    }

    if (!local.rv.success) {
      // local.rv.href = "http://docs.cfwheels.org/2.x/dbmigrate"; // TODO: verify this href
    }

    return local.rv;
  }

  /**
   * Checks for redundant bloat files and extends attributes
   */
  public struct function adviseOfRedundantFiles() {
    local.rv = {
      name="Redundant Files",
      success=true,
      href="",
      messages=[]
    };
    local.wheelsControllerFilePath = ExpandPath("/controllers/Wheels.cfc");
    local.controllerFilePath = ExpandPath("/controllers/Controller.cfc");
    local.controllerCFC = GetComponentMetaData("controllers.Controller");
    local.controllerMapping = "wheels.Controller";
    local.wheelsModelFilePath = ExpandPath("/models/Wheels.cfc");
    local.modelFilePath = ExpandPath("/models/Model.cfc");
    local.modelCFC = GetComponentMetaData("models.Model");
    local.modelMapping = "wheels.Model";

    if (FileExists(local.wheelsControllerFilePath)) {
      local.rv.success = false;
      ArrayAppend(local.rv.messages, {
        message="<code>#_pathFormat(local.wheelsControllerFilePath)#</code> can be deleted."
      });
    }

    if (local.controllerCFC.extends.fullname neq local.controllerMapping) {
      local.rv.success = false;
      ArrayAppend(local.rv.messages, {
        message="<code>#_pathFormat(local.controllerFilePath)#</code> must extend <code>#local.controllerMapping#</code>."
      });
    }

    if (FileExists(local.wheelsModelFilePath)) {
      local.rv.success = false;
      ArrayAppend(local.rv.messages, {
        message="<code>#_pathFormat(local.wheelsModelFilePath)#</code> can be deleted."
      });
    }

    if (local.modelCFC.extends.fullname neq local.modelMapping) {
      local.rv.success = false;
      ArrayAppend(local.rv.messages, {
        message="<code>#_pathFormat(local.modelFilePath)#</code> must extend <code>#local.modelMapping#</code>."
      });
    }

    return local.rv;
  }

  /**
   * Checks for the minimum cfml engine version
   */
  public struct function adviseOfServerVersion() {

    local.rv = {
      name="CFML Engine",
      success=true,
      href="",
      messages=[]
    };

    if (StructKeyExists(server, "lucee")) {
      local.serverName = "Lucee";
      local.serverVersion = server.lucee.version;
    } else if (StructKeyExists(server, "railo")) {
      local.rv.success = false;
      ArrayAppend(local.rv.messages, {
        message="Railo is not supported in Wheels 2.x"
      });
      return local.rv;
    } else {
      local.serverName = "Adobe ColdFusion";
      local.serverVersion = server.coldfusion.productVersion;
    }

    local.upgradeTo = _checkCFMLEngine(engine=local.serverName, version=local.serverVersion);

    if (Len(local.upgradeTo)) {
      local.rv.success = false;
      ArrayAppend(local.rv.messages, {
        message="#local.serverName# #local.serverVersion# is not supported by Wheels 2.x. Please upgrade to version #local.upgradeTo# or higher."
      });
    }

    return local.rv;
  }

  /**
   * Checks that test packages extend the correct component
   */
  public struct function adviseOfTestMappings() {
    local.rv = {
      name="Test Packages",
      success=true,
      href="",
      messages=[]
    };
    local.testDirectoryPath = ExpandPath("/tests");
    local.redundantTestFilePath = ExpandPath("/tests/Test.cfc");
    local.mapping = "wheels.Test";

    if (FileExists(local.redundantTestFilePath)) {
      local.rv.success = false;
      ArrayAppend(local.rv.messages, {
        message="<code>#_pathFormat(local.redundantTestFilePath)#</code> can be deleted."
      });
    }

    // check test file mappings
    if (DirectoryExists(local.testDirectoryPath)) {
      local.allFiles = DirectoryList(local.testDirectoryPath, true, "path", "*.cfc");

      local.files = ArrayFilter(local.allFiles, function(i) {
        // TODO: use GetComponentMetaData
        local.content = FileRead(i);
        return local.content does not contain 'extends="wheels.test"';
      });
      if (ArrayLen(local.files)) {
        local.rv.success = false;
        ArrayAppend(local.rv.messages, {
          message="
            You have #ArrayLen(local.files)# test packages that should extend <code>#local.mapping#</code>
            (Unless you have implemented your own base test component, in which case it should extend <code>#local.mapping#</code>).
          "
        });
      }
    }

    if (!local.rv.success) {
      local.rv.href = "http://docs.cfwheels.org/2.x/dbmigrate"; // TODO: verify this href
    }

    return local.rv;
  }

  /**
   * Checks for the existence of removed javascript arguments in view helpers
   */
  public struct function adviseOfRemovedViewFunctions() {
    local.rv = {
      name="Views",
      success=true,
      href="",
      messages=[]
    };

    local.viewDirectoryPath = ExpandPath("/views");

    if (DirectoryExists(local.viewDirectoryPath)) {
      local.allFiles = DirectoryList(local.viewDirectoryPath, true, "path", "*.cfm|*.cfc");

      local.files = ArrayFilter(local.allFiles, function(i) {
        local.content = FileRead(i);
        return (local.content contains "confirm=" or local.content contains "disable=");
      });
      if (ArrayLen(local.files)) {
        local.rv.success = false;
        local.message = "You have #ArrayLen(local.files)# view files that may be using view helpers with removed <code>confirm</code> or <code>disable</code> arguments.<br>";
        local.message &= "<ul>";
        for (local.i in local.files) {
          local.message &= "<li>#_pathFormat(local.i)#</li>";
        }
        local.message &= "</ul>";
        local.message &= 'You can re-enable these arguments using the <a href="https://github.com/chapmandu/confirmerdisabler" target="_blank">ConfirmerDisabler</a> plugin.';
        ArrayAppend(local.rv.messages, {
          message=local.message
        });
      }
    }

    return local.rv;
  }

  /**
   * Checks for breaking chnages on config settings
   */
  public struct function adviseOfConfigSettings() {
    local.rv = {
      name="Config Settings",
      success=true,
      href="",
      messages=[]
    };

    local.renamedConfigs = [
      {from="clearServerCache", to="clearTemplateCache"},
      {from="modelRequireInit", to="modelRequireConfig"},
      {from="cacheControllerInitialization", to="cacheControllerConfig"},
      {from="cacheModelInitialization", to="cacheModelConfig"}
    ];

    local.configDirectoryPath = ExpandPath("/config");
    local.files = DirectoryList(local.configDirectoryPath, true, "path", "*.cfm");

    local.foundTimeStampMode = false;
    local.messages = [];
    for (local.file in local.files) {
      local.content = FileRead(local.file);
      for (local.config in local.renamedConfigs) {
        if (local.content contains "set(#local.config.from#=") {
          local.rv.success = false;
          ArrayAppend(local.messages, "The global setting <code>#local.config.from#</code> found in <code>#_pathFormat(local.file)#</code> has been renamed to <code>#local.config.to#</code>.")
        }
      }
      if (local.content contains "set(timeStampMode=") {
        local.foundTimeStampMode = true;
      }
    }

    if (!local.foundTimeStampMode) {
      ArrayAppend(local.messages, 'The global setting <code>set(timeStampMode="local")</code> should be used to maintain 1.x behaviour. The 2.x default is <code>UTC</code>');
    }

    if (ArrayLen(local.messages)) {
      for (local.message in local.messages) {
        ArrayAppend(local.rv.messages, {
          message=local.message
        });
      }
    }

    return local.rv;
  }

  /**
   * Checks for the use of the removed updateProperties function
   */
  public struct function adviseOfUpdateProperties() {
    local.rv = {
      name="updateProperties Function",
      success=true,
      href="",
      messages=[]
    };

    local.controllerDirectoryPath = ExpandPath("/controllers");
    local.modelDirectoryPath = ExpandPath("/models");

    local.allFiles = [];
    ArrayAppend(local.allFiles, DirectoryList(local.controllerDirectoryPath, true, "path", "*.cfc"), true);
    ArrayAppend(local.allFiles, DirectoryList(local.modelDirectoryPath, true, "path", "*.cfc"), true);

    local.files = ArrayFilter(local.allFiles, function(i) {
      local.content = FileRead(i);
      return (local.content contains "updateProperties(");
    });

    if (ArrayLen(local.files)) {
      local.rv.success = false;
      local.message = "The <code>updateProperties()</code> method has been removed, use <code>update()</code> instead.<br>";
      local.message &= "<ul>";
      for (local.i in local.files) {
        local.message &= "<li>#_pathFormat(local.i)#</li>";
      }
      local.message &= "</ul>";
      ArrayAppend(local.rv.messages, {
        message=local.message
      });
    }

    return local.rv;
  }

  /**
   * Checks for the existence of csrf use
   */
  public struct function adviseOfCSRF() {
    local.rv = {
      name="Cross Site Request Forgery (CSRF) Protection",
      success=true,
      href="",
      messages=[]
    };

    local.controllerFilePath = ExpandPath("/controllers/Controller.cfc");
    local.viewDirectoryPath = ExpandPath("/views");

    local.controllerContent = FileRead(local.controllerFilePath);
    if (local.controllerContent does not contain "protectFromForgery(") {
      local.rv.success = false;
      ArrayAppend(local.rv.messages, {
        message="It's recommended that you use the <code>protectFromForgery()</code> in the <code>init()</code> function of <code>#_pathFormat(local.controllerFilePath)#</code>"
      });
    }

    if (DirectoryExists(local.viewDirectoryPath)) {
      local.allFiles = DirectoryList(local.viewDirectoryPath, true, "path", "*.cfm");
      for (local.i in local.allFiles) {
        local.content = FileRead(local.i);
        // csrfMetaTags(
        local.containsMetaTags = false;
        if (local.content contains "csrfMetaTags(") {
          local.containsMetaTags = false;
          break;
        }
      }
      if (!local.containsMetaTags) {
        local.rv.success = false;
        ArrayAppend(local.rv.messages, {
          message="It's recommended that you use the <code>csrfMetaTags(</code> in your <code>layout.cfm</code></code>"
        });
        local.rv.href="https://github.com/liquifusion/cfwheels-csrf-protection";
      }
    }

    return local.rv;
  }

  /**
   * Checks for a clashing mapping called 'app'
   */
  public struct function adviseOfAppMapping() {
    local.rv = {
      name="Mappings",
      success=true,
      href="",
      messages=[]
    };

    local.appFileContent = FileRead(ExpandPath("/config/app.cfm"));
    local.mappings = [
      'mappings["/app"]',
      "mappings['/app']"
    ];

    for (local.m in local.mappings) {
      if (local.appFileContent contains local.m) {
        local.rv.success = false;
        ArrayAppend(local.rv.messages, {
          message="Wheels 2.x has created an <code>/app</code> mapping to this application's root (<code>#ExpandPath('/')#</code>). Your mapping should be removed or renamed"
        });
        break;
      }
    }

    return local.rv;
  }

  /**
   * Checks for a clashing mapping called 'app'
   */
  public struct function adviseOfUrlRewriting() {
    local.rv = {
      name="URL Rewriting",
      success=true,
      href="",
      messages=[]
    };

    local.paths = [
      ExpandPath("/.htaccess"),
      ExpandPath("/web.config"),
      ExpandPath("/urlrewrite.xml")
    ];
    local.string = "wheels/public/assets";

    for (local.path in local.paths) {
      if (FileExists(local.path) && FileRead(local.path) does not contain local.string) {
        local.rv.success = false;
        ArrayAppend(local.rv.messages, {
          message="The rule <code>wheels/public/assets</code> is required in your <code>#_pathFormat(local.path)#</code> url rewrite file"
        });
        break;
      }
    }

    return local.rv;
  }

  /**
   * Checks for the init function in controllers & models
   */
  public struct function adviseOfInitRename() {
    local.rv = {
      name="init Function",
      success=true,
      href="",
      messages=[]
    };

    local.controllerDirectoryPath = ExpandPath("/controllers");
    local.modelDirectoryPath = ExpandPath("/models");

    local.allFiles = [];
    ArrayAppend(local.allFiles, DirectoryList(local.controllerDirectoryPath, true, "path", "*.cfc"), true);
    ArrayAppend(local.allFiles, DirectoryList(local.modelDirectoryPath, true, "path", "*.cfc"), true);

    local.files = ArrayFilter(local.allFiles, function(i) {
      // TODO: better to use GetComponentMetaData. but those dotted paths!?
      local.content = FileRead(i);
      return (local.content contains 'name="init"' OR local.content contains "name='init'" OR local.content contains "function init(");
    });

    if (ArrayLen(local.files)) {
      local.rv.success = false;
      local.message = "The <code>init</code> function in controllers and models should now be named <code>config</code>.<br>";
      local.message &= "<ul>";
      for (local.i in local.files) {
        local.message &= "<li>#_pathFormat(local.i)#</li>";
      }
      local.message &= "</ul>";
      ArrayAppend(local.rv.messages, {
        message=local.message
      });
    }

    return local.rv;
  }

  /**
   * Removes the file path before the app root
   */
  private string function _pathFormat(required string path) {
    return ReplaceNoCase(arguments.path, ExpandPath("/"), "/", "one");
  }

  /**
   * Plagiarises the wheels $checkMinimumVersion function
   */
  private string function _checkCFMLEngine(required string engine, required string version) {
    local.rv = "";
    local.version = Replace(arguments.version, ".", ",", "all");
    local.major = ListGetAt(local.version, 1);
    local.minor = 0;
    local.patch = 0;
    if (ListLen(local.version) > 1) {
      local.minor = ListGetAt(local.version, 2);
    }
    if (ListLen(local.version) > 2) {
      local.patch = ListGetAt(local.version, 3);
    }
    if (arguments.engine == "Lucee") {
      local.minimumMajor = "4";
      local.minimumMinor = "5";
      local.minimumPatch = "1";
    } else if (arguments.engine == "Adobe ColdFusion") {
      local.minimumMajor = "11";
      local.minimumMinor = "0";
      local.minimumPatch = "11";
      // local.10 = {minimumMinor=0, minimumPatch=4};
    }
    if (local.major < local.minimumMajor || (local.major == local.minimumMajor && local.minor < local.minimumMinor) || (local.major == local.minimumMajor && local.minor == local.minimumMinor && local.patch < local.minimumPatch)) {
      local.rv = local.minimumMajor & "." & local.minimumMinor & "." & local.minimumPatch;
    }
    if (StructKeyExists(local, local.major)) {
      // special requirements for having a specific minor or patch version within a major release exists
      if (local.minor < local[local.major].minimumMinor || (local.minor == local[local.major].minimumMinor && local.patch < local[local.major].minimumPatch)) {
        local.rv = local.major & "." & local[local.major].minimumMinor & "." & local[local.major].minimumPatch;
      }
    }
    return local.rv;
  }

}
