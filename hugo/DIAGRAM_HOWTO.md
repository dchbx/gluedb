# Diagrams

The diagrams directory exists so that we can have PlantUML diagrams in our Hugo documentation.

First **install Graphviz**.

This is subject to a couple major constraints, because of the way hugo works:
1. Hugo can not build them as part of it's automatic build process - they have to be pre-compiled into the diagrams directory and will be copied over to static assets before hugo builds.
2. As a consequence of the build process - you will need to rebuild the site after you change a diagram to see the update.

Because of this, use the `hugo_server.sh` script (which will run PlantUML for you).

## Justification

First of all, why are we not using Mermaid since it's already supported inline in Hugo?

I **want** to use Mermaid, but it has two current issues that currently make it impossible to use for our projects:
1. It does not support the Package element
2. It does not allow complex class names, such as `EnrollmentEvent::Renewal`.
3. This means that for all intents and purposes we can not use it to diagram many of our classes, as they are namespaced.

## How to Make a Diagram

Here's how you get a working diagram:
1. Create a new *.puml diagram file in the `diagrams` folder.
2. Link the output diagram as an image in your Hugo template as if it were an SVG file in the images directory. This will take the form: `![Image Alt Text](/images/<image_name_here>.svg)` - notice how you chop of the 'puml' extension
3. Make sure you run the `hugo_server.sh` script to start Hugo.

Example:
1. I have a new PlantUML diagram in `diagrams/my_model.puml`
2. I have put in the Hugo template: `![My Model](/images/my_model.svg)`