****CFWheels 2.x Upgrade Advisor****
====================================
***Checks your Wheels 1.x application for compatibility with Wheels 2.x***

**_Upgrade Instructions_**
1. Install this plugin into your CFWheels 1.x application
2. Click the "UpgradeAdvisor" plugin link in the CFWheels debug information panel at the bottom of your page
3. Copy &amp; save this information to plan your migration to CFWheels 2.x
4. Upgrade to CFWheels 2.x by replacing your application's `/wheels` directory with the latest release **^ See note below**
5. Move `/events/functions.cfm` to `/global/functions.cfm`
6. Rename your application's controller and model `init` functions to `config`
7. Click the "UpgradeAdvisor" plugin link in the CFWheels debug information panel at the bottom of your page
8. Resolve the issues found (Use the `reload=true` url parameter to ensure changes are reflected)
9. Verify your application is working as expected

**^ Due to the breaking changes in CFWheels 2.x, your application may be unresponsive between steps 4 and 6.**

*Disclaimer: This tool has been developed as a guide only. The contributors take no responsibility for anything positive or negative that happens as a result of using this plugin. Please use your test suite (you do have a test suite right?) and due diligence when performing upgrades*
