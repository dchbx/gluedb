#Gluedb

*This document is intended for the internal development team.*

##Setup

###Setup the Rails Project

Some of the gems are private, and you will need to consult devops for access.

```
git clone https://github.com/dchbx/gluedb.git
cd gluedb
bundle install
```

###Setup Mongodb

You will need mongo <= 3.4.

```
brew install mongodb
```

Start Mongodb Daemon
```
mongod
```

Get the mongodb dump (ask a team member). Go to the directory where the dump director resides (i.e. one level above dump directory).
```
mongorestore
```

### License

The software is available as open source under the terms of the MIT License (MIT)

Copyright (c) 2014-2021 IdeaCrew, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
