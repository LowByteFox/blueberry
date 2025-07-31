module blueberry;
import std::io;

import blueberry::db;
import blueberry::generic_db;

struct User {
    int id;
    String username;
    int key_id;
}

struct PublicKey {
    int id;
    String type;
    String key;
    String domain;
}

struct UserComplete {
    int uid;
    String username, key_type, key, key_domain;
}

fn int main(String[] args)
{
    Driver drv = db::open("users.db");
    defer drv.close();
    db::new_table(&drv, User, "Users");
    db::new_table(&drv, PublicKey, "Keys");

    User u1 = { 0, "foo", 1 };
    User u2 = { 0, "bar", 2 };
    PublicKey k1 = { 0, "ed25519", "xyz", "example.com" };
    PublicKey k2 = { 0, "rsa", "abc", "example.net" };

    generic_db::insert_into{User}(&drv, "Users", &u1);
    generic_db::insert_into{User}(&drv, "Users", &u2);

    generic_db::insert_into{PublicKey}(&drv, "Keys", &k1);
    generic_db::insert_into{PublicKey}(&drv, "Keys", &k2);

    drv.prepare(`
SELECT Users.id, Users.username, Keys.type, Keys.key, Keys.domain
FROM Users
LEFT JOIN Keys ON Users.key_id = Keys.id
`);
    @pool() {
        UserComplete[] users = generic_db::tcollect{UserComplete}(&drv);
        foreach (user : users) {
            io::printn(user);
        }
    };
	return 0;
}
