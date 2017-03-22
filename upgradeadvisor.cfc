component output="false" {

  public any function init() {
    this.version = "2.0";
    return this;
  }

  /**
   * This plugin version number
   */
  public string function pluginVersion() {
    return "0.1.0";
  }

  /**
   * The main entry function that compiles the check results
   */
  public array function main() {
    local.advice = [
      adviseOfGlobalFunctions(),
      adviseOfRoutes(),
      adviseOfDBMigrate(),
      adviseOfRedundantFiles(),
      adviseOfServerVersion(),
      adviseOfTestMappings(),
      adviseOfRemovedViewFunctions(),
      adviseOfClearServerCache(),
      adviseOfUpdateProperties()
    ];

    local.rv = [];
    // put problems first
    for (local.i in local.advice) {
      if (i.success) {
        ArrayPrepend(local.rv, local.i);
      } else {
        ArrayAppend(local.rv, local.i);
      }
    }

    return local.rv;
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
        message="The <code>addRoute</code> function has been removed from Wheels 2.0. Use the new <code>drawRoutes</code> function/s"
      });
    }

    if (DirectoryExists(local.pluginDirectoryPath)) {
      local.rv.success = false;
      ArrayAppend(local.rv.messages, {
        message="The coldroute plugin is now part of the Wheels 2.0 core. It can be removed."
      });
    }

    if (!local.rv.success) {
      local.rv.href = "http://docs.cfwheels.org/v2.0/docs/routing";
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
        message="The dbmigrate plugin is now part of the Wheels 2.0 core. It can be removed."
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
      // local.rv.href = "http://docs.cfwheels.org/2.0/dbmigrate"; // TODO: verify this href
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
        message="Railo is not supported in Wheels 2.0"
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
        message="#local.serverName# #local.serverVersion# is not supported by Wheels 2.0. Please upgrade to version #local.upgradeTo# or higher."
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
      local.rv.href = "http://docs.cfwheels.org/2.0/dbmigrate"; // TODO: verify this href
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
   * Checks for the use of the renamed clearServerCache setting
   */
  public struct function adviseOfClearServerCache() {
    local.rv = {
      name="clearServerCache Function",
      success=true,
      href="",
      messages=[]
    };

    local.configDirectoryPath = ExpandPath("/config");

    local.allFiles = DirectoryList(local.configDirectoryPath, true, "path", "*.cfm");
    
    local.files = ArrayFilter(local.allFiles, function(i) {
      local.content = FileRead(i);
      return local.content contains "set(clearServerCache=";
    });

    if (ArrayLen(local.files)) {
      local.rv.success = false;

      local.message = "The global setting <code>clearServerCache</code> has been renamed to <code>clearTemplateCache</code>.<br>";
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
      local.minimumMajor = "10";
      local.minimumMinor = "0";
      local.minimumPatch = "16";
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
