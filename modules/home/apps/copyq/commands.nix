{ ... }:

{
  xdg.configFile."copyq/copyq-commands.ini".text = ''
[Commands]

7\Command="copyq:${builtins.readFile ./scripts/dfir-classifier.js}"
7\Automatic=true
7\Icon=
7\InMenu=true
7\Input=text/plain
7\InternalId=dfir_auto_classifier
7\Name=DFIR Auto Classifier

size=7
'';
}
