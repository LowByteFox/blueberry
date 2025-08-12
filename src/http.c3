module blueberry::http;

import std::io;
import std::collections::map;

enum ParserState {
    START,
    HEADERS,
    DONE
}

struct Parser {
    ParserState state;
    Request request;
    usz body_start;
}

struct Request {
    String method, path;
    HashMap{String, String} headers;
}

fn void Parser.init(&self, Allocator alloc)
{
    self.request.headers.init(alloc);
}

fn void Parser.tinit(&self) => self.init(tmem);

<*
 Parses HTTP

 @return "if true, requires more data"
*>
fn bool? Parser.parse(&self, String buffer)
{
    switch (self.state) {
    case START:
        usz iter = 0;
        usz end = buffer.index_of_char(' ')!;
        self.request.method = buffer[iter..end - 1];
        iter = end + 1;
        end = buffer.index_of_char_from(' ', iter)!;
        self.request.path = buffer[iter..end - 1];
        end = buffer.index_of_char_from('\n', iter)!;
        iter = end;
        self.state = HEADERS;

        while (buffer[iter - 1] == '\r' && buffer[iter + 1] != '\r') {
            iter += self.parse_header((String) buffer[iter + 1..])!;
        }

        self.body_start = iter + 3;
        self.state = DONE;
    default:
    }
    return false;
}

<*
 @return "return length to offset iterator"
*>
fn usz? Parser.parse_header(&self, String buffer) @local
{
    switch (self.state) {
    case HEADERS:
        usz iter = 0;
        usz end = buffer.index_of_char(':')!;
        String name = buffer[iter..end - 1];
        iter = end + 2;
        end = buffer.index_of_char_from('\r', iter)!;
        String key = buffer[iter..end - 1];

        self.request.headers[name] = key;

        return end + 2;
    default:
        
    }

    return 0;
}
