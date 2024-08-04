import ballerina/http;
import ballerina/io;
import ballerina/random;
import ballerinax/postgresql;
import ballerinax/postgresql.driver as _;

type World record {|
    int id;
    int randomNumber;
|};

type Fortune record {|
    int id;
    string message;
|};
//"jdbc:postgresql://tfb-database/hello_world?useSSL=false"
final postgresql:Client dbClient = check new ("tfb-database", "benchmarkdbuser", "benchmarkdbpass", "hello_world");

service / on new http:Listener(8080) {

    # Test 1
    resource function get 'json() returns map<string> {
        return {"message": "Hello, World!"};
    }

    # Test 2
    resource function get db() returns World|error {
        return self.queryDb();
    }

    isolated function queryDb() returns World|error {
        var randomId = check random:createIntInRange(1, 10000);
        World result = check dbClient->queryRow(`SELECT id, randomNumber FROM World WHERE id = ${randomId}`);
        return result;
    }

    # Test 3
    isolated resource function get queries(@http:Query string? queries) returns World[]|error {
        io:println("start");
        int queriesInternal;
        if queries is () {
            queriesInternal = 1;
        } else {
            var castedQueries = int:fromString(queries);
            if castedQueries is error || castedQueries < 1 {
                queriesInternal = 1;
            } else {
                queriesInternal = int:min(500, castedQueries);
            }
        }
        World[] result = [];
        foreach int i in int:range(0, queriesInternal, 1) {
            var randomId = check random:createIntInRange(1, 10000);
            World world = check dbClient->queryRow(`SELECT id, randomNumber FROM World WHERE id = ${randomId}`);
            result.push(world);
            io:println("mid", result.length());
        }
        io:println("end", result.length());

        //future<World|error>[] workers = [];
        //foreach int i in int:range(0, queriesInternal, 1) {
        //    future<World|error> w = start self.queryDb();
        //    workers.push(w);
        //}
        //
        //foreach future<World|error> w in workers {
        //    World r = check wait w;
        //    result.push(r);
        //}
        return result;
    }

    # Test 4
    resource function get fortunes() returns string|error {
        stream<Fortune, error?> fortuneStream = dbClient->query(`SELECT id, message FROM Fortune`);
        Fortune[] fortuneArray = check from var fortune in fortuneStream
            select fortune;

        fortuneArray.push({id: 0, message: "Additional fortune added at request time."});
        fortuneArray = fortuneArray.sort(key = isolated function(Fortune f) returns string {
            return f.message;
        });
        // TODO escape f.message
        return string `<!DOCTYPE html>
 <html>
 <head><title>Fortunes</title></head>
 <body>
 <table>
 <tr><th>id</th><th>message</th></tr>
 ${string:'join("\n", ...fortuneArray.'map((f) => string `<tr><td>${f.id}</td><td>${f.message}</td></tr>`))}
 </table>
 </body>
 </html>
 `;
    }

    # Test 5
    resource function get updates(@http:Query string? queries) returns World[]|error {
        int queriesInternal;
        if queries is () {
            queriesInternal = 1;
        } else {
            var castedQueries = int:fromString(queries);
            if castedQueries is error || castedQueries < 1 {
                queriesInternal = 1;
            } else {
                queriesInternal = int:min(500, castedQueries);
            }
        }

        World[] result = [];
        future<World|error>[] workers = [];
        foreach int i in int:range(0, queriesInternal, 1) {
            future<World|error> w = start self.queryDb();
            workers.push(w);
        }

        foreach future<World|error> w in workers {
            World r = check wait w;
            result.push(r);
        }

        future<error?>[] workers1 = [];
        var f = isolated function(World world) returns error? {
            var randomId = check random:createIntInRange(1, 10000);
            while randomId == world.randomNumber {
                randomId = check random:createIntInRange(1, 10000);
            }
            world.randomNumber = randomId;
            _ = check dbClient->execute(`UPDATE World SET randomNumber = ${world.randomNumber} WHERE id = ${world.id}`);
        };
        foreach var world in result {
            future<error?> w = start f(world);
            workers1.push(w);
        }

        foreach future<error?> w in workers1 {
            _ = check wait w;
        }

        return result;
    }

    # Test 6
    resource function get plaintext() returns string {
        return "Hello, World!";
    }
}
