module blueberry;
import std::io;
import std::net, std::net::tcp, std::net::os;
import std::collections::list;
import std::collections::map;

fn int main(String[] args)
{
    TcpServerSocket server = tcp::listen("127.0.0.1", 3000, 1024,
        SocketOption.REUSEADDR)!!;
    List{Poll} fds;
    fds.init(mem);

    HashMap{NativeSocket, TcpSocket} clients;
    clients.init(mem);

    Poll serv;
    serv.socket = server.sock;
    serv.events = os::POLLIN;
    fds.push(serv);

    while (true) {
        Poll[] polls = fds.entries[:fds.size];
        net::poll(polls, net::POLL_FOREVER)!!;

        List{NativeSocket} to_remove;
        to_remove.init(mem);
        defer to_remove.free();

        for (ulong i = 0; i < polls.len; i++) {
            if (polls[i].revents & os::POLLIN) {
                if (polls[i].socket == server.sock) {
                    TcpSocket client = tcp::accept(&server)!!;
                    Poll cl;
                    cl.socket = client.sock;
                    cl.events = net::SUBSCRIBE_ANY_READ;
                    fds.push(cl);
                    clients[client.sock] = client;
                } else {
                    TcpSocket client = clients[polls[i].socket]!!;
                    char[1024] buf;
                    Parser parser;
                    usz len = client.read(buf[..])!!;
                    parser.parse((String) buf[..len])!!;
                    Request req = parser.request;
                    io::printn(req);
                    client.close()!!;

                    clients.remove(polls[i].socket);
                    to_remove.push(polls[i].socket);
                }
            }
        }

        foreach (sock : to_remove) {
            int i = 0;
            for (; i < fds.size; i++) {
                if (fds.entries[i].socket == sock) break;
            }

            fds.remove_at(i);
        }
    }

	return 0;
}
