---
title: Chain of Responsibility
date: 2021-01-18T12:12:25-05:00
draft: false
mermaid: true
---

{{< table_of_contents >}}

## Overview

The Chain of Responsibility is a set of interacting classes and processes in GlueDB which consume Enrollment Events emitted by Enroll and perform data updates and transmissions as a result.

## Flow

The Chain of Responsiblity follows a high level flow of:

1. Recieve Enrollment Events
2. Filter and Reduce duplicate or invalid Enrollment Events
3. Sort and group Enrollment Events into Chunks
4. For each Chunk, determine the qualifying Enrollment Action and perform it

While operating on a group of enrollment actions, the Chain of Responsibilty will also:
1. Send notifications for any duplicate or invalid Enrollment Events dropped or reduced
2. Record the content of the created created chunks and which Enrollment Action was selected

## Enrollment Events

Enrollment Events are the starting point for the Chain of Responsibility.

They take the form of a batch of AMQP messages consumed from a specified queue by GlueDB.

They consist of:

1. An XML payload of type (insert link here)
2. A series of attached headers and properties on the AMQP message providing additional details to be used by the Chain of Responsibilty and for the purpose of tracking and responding to the message.

## Chunks

At a high level, the Chain of Responsiblity operates on a logical grouping of enrollment events called a **Chunk**.

A **Chunk** is a list of enrollment events grouped together because they have been determined by our business rules to interact.

We use the kind and number of events in a Chunk to determine which EnrollmentAction to execute.

Once the chunk has been transformed into an Enrollment Action - we execute the the action to perform changes to our data and to send transmissions to interested parties.

### How Chunks Are Built

Building chunks consists primarily of two operations:

1. `ExternalEvents::EnrollmentEventNotification#edge_for` - this method takes two enrollment events and puts them in the correct order in which they should apply based on our business rules.
2. `ExternalEvents::EnrollmentEventNotification#is_adjacent_to?` - this method takes two enrollment events and determines if they belong in the same **Chunk**.  By the point this method is executed, it is assumed that the events are already sorted using `edge_for`.

### How Chunks Are Used

Chunks, once created, are then used to determine which Enrollment Action is applicable:
1. The chunk is passed to the `EnrollmentAction::Base.qualifies?` method.
2. `EnrollmentAction::Base.qualifies?` invokes the `.qualifies?` method on each subclass of `EnrollmentAction::Base` to find a matching subclass which meets the criteria for the list of enrollment events in the Chunk.

If no Enrollment Actions qualify for the events contained in a Chunk, an error is raised.

Once an Enrollment Action subclass is selected, a new instance of the given class is created using `<subclass>.construct` with the chunk as the primary argument.  Most subclasses of `EnrollmentAction::Base` use the default implementation provided by the superclass.

## Enrollment Actions

**Enrollment Actions** are subclasses of the `EnrollmentAction::Base` class and encapsulate the behaviour to be performed once the scenario indicated by a list of Enrollment Events is known.

New workflow scenarios for GlueDB to perform based on incoming enrollment actions are typically new Enrollment Actions.

Enrollment actions support the following operations:
1. `.qualifies?` which receives a chunk and determines if the events contained within match the scenario the Enrollment Action represents
2. `#persist` which executes any changes to the data stored in GlueDB
3. `#publish` which generates any transactions or transmissions required by interested systems


## Business Process

The overall flow of the chain of responsibility is managed by a series of handlers, composed into a business process.

## Business Process Handlers

{{<mermaid>}}
stateDiagram-v2
  state "Handlers::EnrollmentEventReduceHandler" as a
  state "Handlers::EnrollmentEventEnrichHandler" as b
  state "Handlers::EnrollmentEventPersistHandler" as c
  state "Handlers::EnrollmentEventPublishHandler" as d
  [*] --> a
  a --> b
  b --> c
  c --> d
  d --> [*]
{{< /mermaid >}}