# bashttpd

This is a static file server written in bash

## Usage

Just run `bashttpd.sh` and it will serve files from the current directory.

Operation can be modified with environment variables:
- `ROOT`: root path to serve (default `.`)
- `PORT`: port number to listen on (default `8080`)
- `VERBOSE`: if nonempty, all network i/o will be logged (default `""`)

## FAQ

#### Should I use this for a hobby project?

Probably not.

#### Should I use this for a production service?

Please don't.

#### Should I use this at all?

No.

#### Why would you do this?

Why not?
