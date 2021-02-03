#!/bin/bash
pushd diagrams && java -Djava.awt.headless=true -jar ../plantuml.jar -tsvg -o images *.puml && popd && hugo server
