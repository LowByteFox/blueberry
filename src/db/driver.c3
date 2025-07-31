module blueberry::db;

import sqlite3;

struct Driver {
    SqliteHandle db;
    SqliteStmt stmt;
    ZString err_msg;
    bool used;
}

fn Driver open(ZString file)
{
    Driver dr;
    sqlite3::open(file, &dr.db);
    return dr;
}

fn void Driver.close(&self)
{
    if (self.used) sqlite3::finalize(self.stmt);
    sqlite3::close(self.db);
}

fn void Driver.finalize(&self)
{
    if (self.used) sqlite3::finalize(self.stmt);
}

fn SqliteInt64 Driver.insert_id(&self) => sqlite3::last_insert_id(self.db);

fn ResultStatus Driver.prepare(&self, ZString statement)
{
    self.used = true;
    return sqlite3::prepare_v2(self.db, statement, -1, &self.stmt, null);
}

macro ResultStatus new_table(Driver *drv, $Type, ZString $name) =>
    sqlite3::exec(drv.db, "CREATE TABLE IF NOT EXISTS " +++ $name +++ " " +++ 
        type_to_table($Type) +++ ";", null, null, &drv.err_msg);

macro String type_to_table($Type)
{
    var $out = "(";
    $foreach $i, $el : $Type.membersof:
        $if $i != 0:
            $out = $out +++ ", ";
        $endif

        $out = $out +++ $el.nameof;
        $switch $el.typeid:
        $case ichar:
            $out = $out +++ " TINYINT";
        $case short:
            $out = $out +++ " SMALLINT";
        $case int:
            $out = $out +++ " INTEGER";
        $case long:
            $out = $out +++ " BIGINT";
        $case float:
        $case double:
            $out = $out +++ " REAL";
        $case String:
        $case ZString:
            $out = $out +++ " TEXT";
        $default:
            $error "Unhandled type: " +++ $el.typeid.nameof;
        $endswitch

        $if $i == 0:
            $out = $out +++ " PRIMARY KEY";
        $endif
    $endforeach
    $out = $out +++ ")";

    return $out;
}

macro String type_keys($Type, bool $uninit)
{
    var $out = "(";
    $foreach $i, $el : $Type.membersof:
        $if $i != 0:
            $if $i != 1:
                $out = $out +++ ", ";
            $endif

            $if $uninit:
                $out = $out +++ "?";
            $else
                $out = $out +++ $el.nameof;
            $endif
        $endif
    $endforeach

    return $out +++ ")";
}

module blueberry::generic_db{Type};

import sqlite3;
import blueberry::db;
import std::collections::list;

macro ResultStatus insert_into(Driver *drv, ZString $name, Type *val)
{
    drv.used = true;
    sqlite3::prepare_v2(drv.db, "INSERT INTO " +++ $name +++ " " +++
        db::type_keys(Type, false) +++ " VALUES " +++
        db::type_keys(Type, true) +++ ";", -1, &drv.stmt, null);
    defer drv.used = false;
    defer sqlite3::finalize(drv.stmt);

    bind_value(drv, val);

    return sqlite3::step(drv.stmt);
}

fn Type[] collect(Driver *drv, Allocator alloc)
{
    @pool() {
        List{Type} list;
        list.tinit();

        while (sqlite3::step(drv.stmt) == sqlite3::ROW) {
            Type val;

            $foreach $i, $el : Type.membersof:
                $switch $el.typeid:
                $case ichar:
                $case short:
                $case int:
                    *(int*) &$el.get(val) = sqlite3::column_int(drv.stmt, $i);
                $case long:
                    *(long*) &$el.get(val) = sqlite3::column_int64(drv.stmt,
                        $i);
                $case float:
                $case double:
                    *(double*) &$el.get(val) = sqlite3::column_double(drv.stmt,
                        $i);
                $case String:
                    *(String*) &$el.get(val) = sqlite3::column_text(drv.stmt,
                        $i).str_view().copy(alloc);
                $case ZString:
                    *(ZString*) &$el.get(val) = sqlite3::column_text(drv.stmt,
                        $i).copy(alloc);
                $default:
                    $error "Unhandled type: " +++ $el.typeid.nameof;
                $endswitch
            $endforeach

            list.push(val);
        }

        return list.to_array(alloc);
    };
}

fn Type[] tcollect(Driver *drv) => collect(drv, tmem);

fn void bind_value(Driver *drv, Type *val) 
{
    $foreach $i, $el : Type.membersof:
        $if $i != 0:
            $switch $el.typeid:
            $case ichar:
            $case short:
            $case int:
                sqlite3::bind_int(drv.stmt, $i, $el.get(*val));
            $case long:
                sqlite3::bind_int64(drv.stmt, $i, $el.get(*val));
            $case float:
            $case double:
                sqlite3::bind_double(drv.stmt, $i, $el.get(*val));
            $case String:
                sqlite3::bind_text(drv.stmt, $i, (ZString) $el.get(*val).ptr,
                    $el.get(*val).len, null);
            $case ZString:
                sqlite3::bind_text(drv.stmt, $i, $el.get(*val), -1, null);
            $default:
                $error "Unhandled type: " +++ $el.typeid.nameof;
            $endswitch
        $endif
    $endforeach
}
