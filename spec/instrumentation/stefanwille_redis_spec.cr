require "./stefanwille_redis_spec_helper"
require "../../src/opentelemetry/instrumentation/shards/stefanwille_redis"

# These specs were copied from the original project for this redis shard --
# if the instrumenteded library can pass the original specs, it must work.
# The original is located at:
#   https://github.com/stefanwille/crystal-redis/blob/master/spec/redis_spec.cr
#
# Those specs (and thus any identical code found in this file) is licensed as follows:
#
# Copyright (c) 2015 Stefan Wille
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

if_defined?(Redis::Strategy::SingleStatement) do
  begin
    Redis.new
    redis_is_running = true
  rescue
    redis_is_running = false
  end

  memory = IO::Memory.new

  describe Redis do
    before_all do
      OpenTelemetry.configure do |config|
        config.service_name = "Crystal OTel Instrumentation - Stefan Wille Redis Driver Test"
        config.service_version = OpenTelemetry::VERSION
        config.exporter = OpenTelemetry::Exporter.new(variant: :io, io: memory)
      end
    end

    after_each do
      memory.clear
    end

    describe ".new" do
      if redis_is_running
        it "connects to default host and port" do
          Redis.new
        end
      else
        pending ":redis is not running: connects to default host and port"
      end

      if redis_is_running
        it "connects to specific port and host / disconnects" do
          Redis.new(host: "localhost", port: 6379)
        end
      else
        pending ":redis is not running: connects to specific port and host"
      end

      if redis_is_running
        it "connects to a specific database" do
          redis = Redis.new(host: "localhost", port: 6379, database: 1)
          redis.not_nil!.url.should eq("redis://localhost:6379/1")
        end
      else
        pending ":redis is not running: connects to a specific database"
      end

      # if redis_is_running
      #   it "connects to Unix domain sockets" do
      #     redis = Redis.new(unixsocket: TEST_UNIXSOCKET)
      #     redis.not_nil!.url.should eq("redis://#{TEST_UNIXSOCKET}/0")
      #     redis.not_nil!.ping.should eq "PONG"
      #   end
      # else
      #   pending ":redis is not running: connects to Unix domain sockets"
      # end

      context "when url argument is given" do
        if redis_is_running
          it "connects using given URL" do
            redis = Redis.new(url: "redis://127.0.0.1", host: "host.to.be.ignored", port: 1234)
            redis.not_nil!.url.should eq("redis://127.0.0.1:6379/0")
          end
        else
          pending ":redis is not running: connects using given URL"
        end
      end

      context "when url argument with trailing slash is given" do
        if redis_is_running
          it "connects using given URL" do
            redis = Redis.new(url: "redis://127.0.0.1/")
            redis.not_nil!.url.should eq("redis://127.0.0.1:6379/0")
          end
        else
          pending ":redis is not running: connects using given URL"
        end
      end

      it "raises ConnectionError when it cant connect to redis" do
        expect_raises(Redis::CannotConnectError, /Socket::ConnectError: Error connecting to 'localhost:12345':/) do
          Redis.new(host: "localhost", port: 12345)
        end
      end

      describe "#close" do
        if redis_is_running
          it "closes the connection" do
            redis = Redis.new
            redis.not_nil!.close
          end
        else
          pending ":redis is not running: closes the connection"
        end

        if redis_is_running
          it "tolerates a duplicate call" do
            redis = Redis.new
            redis.not_nil!.close
            redis.not_nil!.close
          end
        else
          pending ":redis is not running: tolerates a duplicate call"
        end
      end
    end

    describe ".open" do
      if redis_is_running
        it "connects to the Redis server using the given connection params, yields its block and disconnects" do
          Redis.open(host: "localhost", port: 6379) do |redis|
            redis.not_nil!.ping
          end
        end
      else
        pending ":redis is not running: connects to the Redis server using the given connection params, yields its block and disconnects"
      end

      if redis_is_running
        it "connects to the Redis using the given url, yields its block and disconnects" do
          Redis.open(url: "redis://127.0.0.1") do |redis|
            redis.not_nil!.ping
          end
        end
      else
        pending ":redis is not running: connects to the Redis using the given url, yields its block and disconnects"
      end
    end

    describe "#url" do
      if redis_is_running
        it "returns the server url" do
          Redis.open do |redis|
            redis.not_nil!.url.should eq("redis://localhost:6379/0")
          end
          Redis.open(url: "redis://127.0.0.1") do |redis|
            redis.not_nil!.url.should eq("redis://127.0.0.1:6379/0")
          end
        end
      else
        pending ":redis is not running: returns the server url"
      end
    end

    if redis_is_running
      it "#ping" do
        Redis.open do |redis|
          redis.not_nil!.ping.should eq("PONG")
        end
      end
    else
      pending ":redis is not running: #ping"
    end

    if redis_is_running
      it "#echo" do
        Redis.open do |redis|
          redis.not_nil!.echo("Ciao").should eq("Ciao")
        end
      end
    else
      pending ":redis is not running: #echo"
    end

    if redis_is_running
      it "#quit" do
        Redis.open do |redis|
          redis.not_nil!.quit.should eq("OK")
        end
      end
    else
      pending ":redis is not running: #quit"
    end

    if redis_is_running
      it "#flushdb" do
        Redis.open do |redis|
          redis.not_nil!.set("foo", "test")
          redis.not_nil!.get("foo").should eq("test")

          redis.not_nil!.flushdb.should eq("OK")

          redis.not_nil!.get("foo").should eq(nil)
        end
      end
    else
      pending ":redis is not running: #flushdb"
    end

    if redis_is_running
      it "#select" do
        Redis.open do |redis|
          redis.not_nil!.select(0).should eq("OK")
        end
      end
    else
      pending ":redis is not running: #select"
    end

    if redis_is_running
      it "#auth" do
        Redis.open do |redis|
          expect_raises(Redis::Error, /ERR.*AUTH/) do
            redis.not_nil!.auth("some-password").should eq("OK")
          end
        end
      end
    else
      pending ":redis is not running: #auth"
    end

    {nil, "my_namespace"}.each do |namespace|
      context "(namespace: #{namespace})" do
        describe "keys" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "#del" do
              redis.not_nil!.set("foo", "test")
              redis.not_nil!.del("foo")
              redis.not_nil!.get("foo").should eq(nil)

              redis.not_nil!.mset({"foo1" => "bar1", "foo2" => "bar2"})
              redis.not_nil!.del(["foo1", "foo2"]).should eq(2)
            end
          else
            pending ":redis is not running: #del"
          end

          if redis_is_running
            it "converts keys to strings" do
              redis.not_nil!.set(:foo, "hello")
              redis.not_nil!.set(123456, 7)
              redis.not_nil!.get("foo").should eq("hello")
              redis.not_nil!.get("123456").should eq("7")
            end
          else
            pending ":redis is not running: converts keys to strings"
          end

          if redis_is_running
            it "#rename" do
              redis.not_nil!.del("foo", "bar")
              redis.not_nil!.set("foo", "test")
              redis.not_nil!.rename("foo", "bar")
              redis.not_nil!.get("bar").should eq("test")
            end
          else
            pending ":redis is not running: #rename"
          end

          if redis_is_running
            it "#renamenx" do
              redis.not_nil!.set("foo", "Hello")
              redis.not_nil!.set("bar", "world")
              redis.not_nil!.renamenx("foo", "bar").should eq(0)
              redis.not_nil!.get("bar").should eq("world")

              client_traces, _server_traces = FindJson.from_io(memory)
              # Spot Check some traces here...

              client_traces.size.should eq 4
              client_traces[0]["spans"][0]["name"].should eq "Redis: GET #{[namespace, "bar"].compact!.join("::")}"
              client_traces[0]["spans"][0]["attributes"]["db.system"].should eq "redis"
              client_traces[0]["spans"][0]["attributes"]["db.statement"].should eq "GET #{[namespace, "bar"].compact!.join("::")}"
              client_traces[0]["spans"][0]["attributes"]["net.transport"].should eq "ip_tcp"
            end
          else
            pending ":redis is not running: #renamenx"
          end

          if redis_is_running
            it "#randomkey" do
              redis.not_nil!.set("foo", "Hello")
              redis.not_nil!.randomkey.should_not be_nil
            end
          else
            pending ":redis is not running: #randomkey"
          end

          if redis_is_running
            it "#exists" do
              redis.not_nil!.del("foo")
              redis.not_nil!.exists("foo").should eq(0)
              redis.not_nil!.set("foo", "test")
              redis.not_nil!.exists("foo").should eq(1)
            end
          else
            pending ":redis is not running: #exists"
          end

          if redis_is_running
            it "#keys" do
              redis.not_nil!.set("callmemaybe", 1)
              redis.not_nil!.keys("callmemaybe").should eq(["callmemaybe"])
            end
          else
            pending ":redis is not running: #keys"
          end

          describe "#sort" do
            if redis_is_running
              it "sorts the container" do
                redis.not_nil!.del("mylist")
                redis.not_nil!.rpush("mylist", "1", "3", "2")
                redis.not_nil!.sort("mylist").should eq(["1", "2", "3"])
                redis.not_nil!.sort("mylist", order: "DESC").should eq(["3", "2", "1"])
              end
            else
              pending ":redis is not running: sorts the container"
            end

            if redis_is_running
              it "limit" do
                redis.not_nil!.del("mylist")
                redis.not_nil!.rpush("mylist", "1", "3", "2")
                redis.not_nil!.sort("mylist", limit: [1, 2]).should eq(["2", "3"])
              end
            else
              pending ":redis is not running: limit"
            end

            if redis_is_running
              it "by" do
                redis.not_nil!.del("mylist", "objects", "weights")
                redis.not_nil!.rpush("mylist", "1", "3", "2")
                redis.not_nil!.mset({"weight_1" => 1, "weight_2" => 2, "weight_3" => 3})
                redis.not_nil!.sort("mylist", by: "weights_*").should eq(["1", "2", "3"])
              end
            else
              pending ":redis is not running: by"
            end

            if redis_is_running
              it "alpha" do
                redis.not_nil!.del("mylist")
                redis.not_nil!.rpush("mylist", "c", "a", "b")
                redis.not_nil!.sort("mylist", alpha: true).should eq(["a", "b", "c"])
              end
            else
              pending ":redis is not running: alpha"
            end

            if redis_is_running
              it "store" do
                redis.not_nil!.del("mylist", "destination")
                redis.not_nil!.rpush("mylist", "1", "3", "2")
                redis.not_nil!.sort("mylist", store: "destination")
                redis.not_nil!.lrange("destination", 0, 2).should eq(["1", "2", "3"])
              end
            else
              pending ":redis is not running: store"
            end
          end

          if redis_is_running
            it "#dump / #restore" do
              Redis.open do |inner_redis|
                inner_redis.not_nil!.set("foo", "9")
                serialized_value = inner_redis.not_nil!.dump("foo")
                inner_redis.not_nil!.del("foo")
                inner_redis.not_nil!.restore("foo", 0, serialized_value).should eq("OK")
                inner_redis.not_nil!.get("foo").should eq("9")
                inner_redis.not_nil!.ttl("foo").should eq(-1)
              end
            end
          else
            pending ":redis is not running: #dump / #restore"
          end
        end

        describe "select database" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "select database when connect" do
              redis1 = Redis.new(host: "localhost", port: 6379, database: 1, namespace: namespace || "")
              redis2 = Redis.new(host: "localhost", port: 6379, database: 2, namespace: namespace || "")

              redis1.del("test_database")
              redis2.del("test_database")

              redis1.set("test_database", "1")
              redis2.set("test_database", "2")

              redis1.get("test_database").should eq "1"
              redis2.get("test_database").should eq "2"
            end
          else
            pending ":redis is not running: select database when connect"
          end

          if redis_is_running
            it "select database by command" do
              redis1 = Redis.new(host: "localhost", port: 6379, database: 1, namespace: namespace || "")
              redis2 = Redis.new(host: "localhost", port: 6379, database: 2, namespace: namespace || "")

              redis1.del("test_database")
              redis2.del("test_database")

              redis1.set("test_database", "1")
              redis2.set("test_database", "2")

              redis.not_nil!.select(1)
              redis.not_nil!.get("test_database").should eq "1"

              redis.not_nil!.select(2)
              redis.not_nil!.get("test_database").should eq "2"
            end
          else
            pending ":redis is not running: select database by command"
          end

          if redis_is_running
            it "does nothing if current database is the same as given one" do
              redis.not_nil!.select(2).should eq "OK"
              redis.not_nil!.select(1).should eq "OK"
              redis.not_nil!.select(1).should eq "OK"
              # There is no good way to assert that no command was sent
            end
          else
            pending ":redis is not running: does nothing if current database is the same as given one"
          end
        end

        describe "strings" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "#set / #get" do
              redis.not_nil!.set("foo", "test")
              redis.not_nil!.get("foo").should eq("test")
            end
          else
            pending ":redis is not running: #set / #get"
          end

          if redis_is_running
            it "#set options" do
              redis.not_nil!.set("foo", "test", ex: 7)
              redis.not_nil!.ttl("foo").should eq(7)

              redis.not_nil!.set("foo", "test", px: 7)
              redis.not_nil!.ttl("foo").should eq(0)

              redis.not_nil!.set("foo", "test", nx: true)

              redis.not_nil!.set("foo", "test", xx: true)
            end
          else
            pending ":redis is not running: #set options"
          end

          if redis_is_running
            it "#mget" do
              redis.not_nil!.set("foo1", "test1")
              redis.not_nil!.set("foo2", "test2")
              redis.not_nil!.mget("foo1", "foo2").should eq(["test1", "test2"])
              redis.not_nil!.mget(["foo2", "foo1"]).should eq(["test2", "test1"])
            end
          else
            pending ":redis is not running: #mget"
          end

          if redis_is_running
            it "#mset" do
              redis.not_nil!.mset({"foo1" => "bar1", "foo2" => "bar2"})
              redis.not_nil!.get("foo1").should eq("bar1")
              redis.not_nil!.get("foo2").should eq("bar2")
            end
          else
            pending ":redis is not running: #mset"
          end

          if redis_is_running
            it "#getset" do
              redis.not_nil!.set("foo", "old")
              redis.not_nil!.getset("foo", "new").should eq("old")
              redis.not_nil!.get("foo").should eq("new")
            end
          else
            pending ":redis is not running: #getset"
          end

          if redis_is_running
            it "#setex" do
              redis.not_nil!.setex("foo", 3, "setexed")
              redis.not_nil!.get("foo").should eq("setexed")
            end
          else
            pending ":redis is not running: #setex"
          end

          if redis_is_running
            it "#psetex" do
              redis.not_nil!.psetex("foo", 3000, "psetexed")
              redis.not_nil!.get("foo").should eq("psetexed")
            end
          else
            pending ":redis is not running: #psetex"
          end

          if redis_is_running
            it "#setnx" do
              redis.not_nil!.del("foo")
              redis.not_nil!.setnx("foo", "setnxed").should eq(1)
              redis.not_nil!.get("foo").should eq("setnxed")
              redis.not_nil!.setnx("foo", "setnxed2").should eq(0)
              redis.not_nil!.get("foo").should eq("setnxed")
            end
          else
            pending ":redis is not running: #setnx"
          end

          if redis_is_running
            it "#msetnx" do
              redis.not_nil!.del("key1", "key2", "key3")
              redis.not_nil!.msetnx({"key1": "hello", "key2": "there"}).should eq(1)
              redis.not_nil!.get("key1").should eq("hello")
              redis.not_nil!.get("key2").should eq("there")
              redis.not_nil!.msetnx({"key2": "keep", "key3": "singing"}).should eq(0)
              redis.not_nil!.get("key1").should eq("hello")
              redis.not_nil!.get("key2").should eq("there")
              redis.not_nil!.get("key3").should eq(nil)
            end
          else
            pending ":redis is not running: #msetnx"
          end

          if redis_is_running
            it "#incr" do
              redis.not_nil!.set("foo", "3")
              redis.not_nil!.incr("foo").should eq(4)
            end
          else
            pending ":redis is not running: #incr"
          end

          if redis_is_running
            it "#decr" do
              redis.not_nil!.set("foo", "3")
              redis.not_nil!.decr("foo").should eq(2)
            end
          else
            pending ":redis is not running: #decr"
          end

          if redis_is_running
            it "#incrby" do
              redis.not_nil!.set("foo", "10")
              redis.not_nil!.incrby("foo", 4).should eq(14)
            end
          else
            pending ":redis is not running: #incrby"
          end

          if redis_is_running
            it "#decrby" do
              redis.not_nil!.set("foo", "10")
              redis.not_nil!.decrby("foo", 4).should eq(6)
            end
          else
            pending ":redis is not running: #decrby"
          end

          if redis_is_running
            it "#incrbyfloat" do
              redis.not_nil!.set("foo", "10")
              redis.not_nil!.incrbyfloat("foo", 2.5).should eq("12.5")
            end
          else
            pending ":redis is not running: #incrbyfloat"
          end

          if redis_is_running
            it "#append" do
              redis.not_nil!.set("foo", "hello")
              redis.not_nil!.append("foo", " world")
              redis.not_nil!.get("foo").should eq("hello world")
            end
          else
            pending ":redis is not running: #append"
          end

          if redis_is_running
            it "#strlen" do
              redis.not_nil!.set("foo", "Hello world")
              redis.not_nil!.strlen("foo").should eq(11)
              redis.not_nil!.del("foo")
              redis.not_nil!.strlen("foo").should eq(0)
            end
          else
            pending ":redis is not running: #strlen"
          end

          if redis_is_running
            it "#getrange" do
              redis.not_nil!.set("foo", "This is a string")
              redis.not_nil!.getrange("foo", 0, 3).should eq("This")
              redis.not_nil!.getrange("foo", -3, -1).should eq("ing")
            end
          else
            pending ":redis is not running: #getrange"
          end

          if redis_is_running
            it "#setrange" do
              redis.not_nil!.set("foo", "Hello world")
              redis.not_nil!.setrange("foo", 6, "Redis").should eq(11)
              redis.not_nil!.get("foo").should eq("Hello Redis")
            end
          else
            pending ":redis is not running: #setrange"
          end

          describe "#scan" do
            if redis_is_running
              it "no options" do
                redis.not_nil!.set("foo", "Hello world")
                new_cursor, keys = redis.not_nil!.scan(0)
                new_cursor = new_cursor.as(String)
                new_cursor.to_i.should be > 0
                keys.is_a?(Array).should be_true
              end
            else
              pending ":redis is not running: no options"
            end

            if redis_is_running
              it "with match" do
                redis.not_nil!.set("scan.match1", "1")
                redis.not_nil!.set("scan.match2", "2")
                new_cursor, keys = redis.not_nil!.scan(0, "scan.match*")
                new_cursor = new_cursor.as(String)
                new_cursor.to_i.should be > 0
                keys.is_a?(Array).should be_true
                # Here `keys.size` should be 0 or 1 or 2, but I don't know how to test it.
              end
            else
              pending ":redis is not running: with match"
            end

            if redis_is_running
              it "with match and count" do
                redis.not_nil!.set("scan.match1", "1")
                redis.not_nil!.set("scan.match2", "2")
                new_cursor, keys = redis.not_nil!.scan(0, "scan.match*", 1)
                new_cursor = new_cursor.as(String)
                new_cursor.to_i.should be > 0
                keys.is_a?(Array).should be_true
                # Here `keys.size` should be 0 or 1, but I don't know how to test it.
              end
            else
              pending ":redis is not running: with match and count"
            end

            if redis_is_running
              it "with match and count at once" do
                redis.not_nil!.set("scan.match1", "1")
                redis.not_nil!.set("scan.match2", "2")
                # assumes that current Redis instance has at most 10M entries
                new_cursor, keys = redis.not_nil!.scan(0, "scan.match*", 10_000_000)
                new_cursor.should eq("0")
                array(keys).sort.should eq(["scan.match1", "scan.match2"])
              end
            else
              pending ":redis is not running: with match and count at once"
            end
          end
        end

        describe "bit operations" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "#bitcount" do
              redis.not_nil!.set("foo", "foobar")
              redis.not_nil!.bitcount("foo", 0, 0).should eq(4)
              redis.not_nil!.bitcount("foo", 1, 1).should eq(6)
            end
          else
            pending ":redis is not running: #bitcount"
          end

          if redis_is_running
            it "#bitop" do
              redis.not_nil!.set("key1", "foobar")
              redis.not_nil!.set("key2", "abcdef")
              redis.not_nil!.bitop("and", "dest", "key1", "key2").should eq(6)
              redis.not_nil!.get("dest").should eq("`bc`ab")
            end
          else
            pending ":redis is not running: #bitop"
          end

          if redis_is_running
            it "#bitpos" do
              redis.not_nil!.set("mykey", "0")
              redis.not_nil!.bitpos("mykey", 1).should eq(2)
            end
          else
            pending ":redis is not running: #bitpos"
          end

          if redis_is_running
            it "#getbit / #setbit" do
              redis.not_nil!.del("mykey")
              redis.not_nil!.setbit("mykey", 7, 1).should eq(0)
              redis.not_nil!.getbit("mykey", 0).should eq(0)
              redis.not_nil!.getbit("mykey", 7).should eq(1)
              redis.not_nil!.getbit("mykey", 100).should eq(0)
            end
          else
            pending ":redis is not running: #getbit / #setbit"
          end
        end

        describe "lists" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "#rpush / #lrange" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.rpush("mylist", "hello").should eq(1)
              redis.not_nil!.rpush("mylist", "world").should eq(2)
              redis.not_nil!.lrange("mylist", 0, 1).should eq(["hello", "world"])
              redis.not_nil!.rpush("mylist", "snip", "snip").should eq(4)
            end
          else
            pending ":redis is not running: #rpush / #lrange"
          end

          if redis_is_running
            it "#lpush" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.lpush("mylist", "hello").should eq(1)
              redis.not_nil!.lpush("mylist", ["world"]).should eq(2)
              redis.not_nil!.lrange("mylist", 0, 1).should eq(["world", "hello"])
              redis.not_nil!.lpush("mylist", "snip", "snip").should eq(4)
            end
          else
            pending ":redis is not running: #lpush"
          end

          if redis_is_running
            it "#lpushx" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.lpushx("mylist", "hello").should eq(0)
              redis.not_nil!.lrange("mylist", 0, 1).should eq([] of Redis::RedisValue)
              redis.not_nil!.lpush("mylist", "hello")
              redis.not_nil!.lpushx("mylist", "world").should eq(2)
              redis.not_nil!.lrange("mylist", 0, 1).should eq(["world", "hello"])
            end
          else
            pending ":redis is not running: #lpushx"
          end

          if redis_is_running
            it "#rpushx" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.rpushx("mylist", "hello").should eq(0)
              redis.not_nil!.lrange("mylist", 0, 1).should eq([] of Redis::RedisValue)
              redis.not_nil!.rpush("mylist", "hello")
              redis.not_nil!.rpushx("mylist", "world").should eq(2)
              redis.not_nil!.lrange("mylist", 0, 1).should eq(["hello", "world"])
            end
          else
            pending ":redis is not running: #rpushx"
          end

          if redis_is_running
            it "#lrem" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.rpush("mylist", "hello")
              redis.not_nil!.rpush("mylist", "my")
              redis.not_nil!.rpush("mylist", "world")
              redis.not_nil!.lrem("mylist", 1, "my").should eq(1)
              redis.not_nil!.lrange("mylist", 0, 1).should eq(["hello", "world"])
              redis.not_nil!.lrem("mylist", 0, "world").should eq(1)
              redis.not_nil!.lrange("mylist", 0, 1).should eq(["hello"])
            end
          else
            pending ":redis is not running: #lrem"
          end

          if redis_is_running
            it "#llen" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.lpush("mylist", "hello")
              redis.not_nil!.lpush("mylist", "world")
              redis.not_nil!.llen("mylist").should eq(2)
            end
          else
            pending ":redis is not running: #llen"
          end

          if redis_is_running
            it "#lset" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.rpush("mylist", "hello")
              redis.not_nil!.rpush("mylist", "world")
              redis.not_nil!.lset("mylist", 0, "goodbye").should eq("OK")
              redis.not_nil!.lrange("mylist", 0, 1).should eq(["goodbye", "world"])
            end
          else
            pending ":redis is not running: #lset"
          end

          if redis_is_running
            it "#lindex" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.rpush("mylist", "hello")
              redis.not_nil!.rpush("mylist", "world")
              redis.not_nil!.lindex("mylist", 0).should eq("hello")
              redis.not_nil!.lindex("mylist", 1).should eq("world")
              redis.not_nil!.lindex("mylist", 2).should eq(nil)
            end
          else
            pending ":redis is not running: #lindex"
          end

          if redis_is_running
            it "#lpop" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.rpush("mylist", "hello")
              redis.not_nil!.rpush("mylist", "world")
              redis.not_nil!.lpop("mylist").should eq("hello")
              redis.not_nil!.lpop("mylist").should eq("world")
              redis.not_nil!.lpop("mylist").should eq(nil)
            end
          else
            pending ":redis is not running: #lpop"
          end

          if redis_is_running
            it "#rpop" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.rpush("mylist", "hello")
              redis.not_nil!.rpush("mylist", "world")
              redis.not_nil!.rpop("mylist").should eq("world")
              redis.not_nil!.rpop("mylist").should eq("hello")
              redis.not_nil!.rpop("mylist").should eq(nil)
            end
          else
            pending ":redis is not running: #rpop"
          end

          if redis_is_running
            it "#linsert" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.rpush("mylist", "hello")
              redis.not_nil!.rpush("mylist", "world")
              redis.not_nil!.linsert("mylist", :before, "world", "dear").should eq(3)
              redis.not_nil!.lrange("mylist", 0, 2).should eq(["hello", "dear", "world"])
            end
          else
            pending ":redis is not running: #linsert"
          end

          if redis_is_running
            it "#blpop" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.del("myotherlist")
              redis.not_nil!.rpush("mylist", "hello", "world")
              redis.not_nil!.blpop(["myotherlist", "mylist"], 1).should eq(["mylist", "hello"])
            end
          else
            pending ":redis is not running: #blpop"
          end

          if redis_is_running
            it "#blpop with no data, should not raise" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.del("myotherlist")
              redis.not_nil!.blpop(["myotherlist", "mylist"], 1).should eq([] of String)
            end
          else
            pending ":redis is not running: #blpop"
          end

          if redis_is_running
            it "#ltrim" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.rpush("mylist", "hello", "good", "world")
              redis.not_nil!.ltrim("mylist", 0, 0).should eq("OK")
              redis.not_nil!.lrange("mylist", 0, 2).should eq(["hello"])
            end
          else
            pending ":redis is not running: #ltrim"
          end

          if redis_is_running
            it "#brpop" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.del("myotherlist")
              redis.not_nil!.rpush("mylist", "hello", "world")
              redis.not_nil!.brpop(["myotherlist", "mylist"], 1).should eq(["mylist", "world"])

              redis.not_nil!.del("mylist")
              redis.not_nil!.brpop(["mylist"], 1).should eq([] of String)
            end
          else
            pending ":redis is not running: #brpop"
          end

          if redis_is_running
            it "#brpop with no data, should not raise" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.del("myotherlist")
              redis.not_nil!.brpop(["myotherlist", "mylist"], 1).should eq([] of String)
            end
          else
            pending ":redis is not running: #brpop"
          end

          if redis_is_running
            it "#rpoplpush" do
              redis.not_nil!.del("source")
              redis.not_nil!.del("destination")
              redis.not_nil!.rpush("source", "a", "b", "c")
              redis.not_nil!.rpush("destination", "1", "2", "3")
              redis.not_nil!.rpoplpush("source", "destination")
              redis.not_nil!.lrange("source", 0, 4).should eq(["a", "b"])
              redis.not_nil!.lrange("destination", 0, 4).should eq(["c", "1", "2", "3"])
            end
          else
            pending ":redis is not running: #rpoplpush"
          end

          if redis_is_running
            it "#brpoplpush" do
              redis.not_nil!.del("source")
              redis.not_nil!.del("destination")
              redis.not_nil!.rpush("source", "a", "b", "c")
              redis.not_nil!.rpush("destination", "1", "2", "3")
              redis.not_nil!.brpoplpush("source", "destination", 0)
              redis.not_nil!.lrange("source", 0, 4).should eq(["a", "b"])
              redis.not_nil!.lrange("destination", 0, 4).should eq(["c", "1", "2", "3"])

              # timeout test (#68)
              redis.not_nil!.del("source")
              redis.not_nil!.brpoplpush("source", "destination", 1).should eq(nil)
            end
          else
            pending ":redis is not running: #brpoplpush"
          end
        end

        describe "sets" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "#sadd / #smembers" do
              redis.not_nil!.del("myset")
              redis.not_nil!.sadd("myset", "Hello").should eq(1)
              redis.not_nil!.sadd("myset", "World").should eq(1)
              redis.not_nil!.sadd("myset", "World").should eq(0)
              redis.not_nil!.sadd("myset", ["Foo", "Bar"]).should eq(2)
              sort(redis.not_nil!.smembers("myset")).should eq(["Bar", "Foo", "Hello", "World"])
            end
          else
            pending ":redis is not running: #sadd / #smembers"
          end

          if redis_is_running
            it "#scard" do
              redis.not_nil!.del("myset")
              redis.not_nil!.sadd("myset", "Hello", "World")
              redis.not_nil!.scard("myset").should eq(2)
            end
          else
            pending ":redis is not running: #scard"
          end

          if redis_is_running
            it "#sismember" do
              redis.not_nil!.del("key1")
              redis.not_nil!.sadd("key1", "a")
              redis.not_nil!.sismember("key1", "a").should eq(1)
              redis.not_nil!.sismember("key1", "b").should eq(0)
            end
          else
            pending ":redis is not running: #sismember"
          end

          if redis_is_running
            it "#srem" do
              redis.not_nil!.del("myset")
              redis.not_nil!.sadd("myset", "Hello", "World")
              redis.not_nil!.srem("myset", "Hello").should eq(1)
              redis.not_nil!.smembers("myset").should eq(["World"])

              redis.not_nil!.sadd("myset", ["Hello", "World", "Foo"])
              redis.not_nil!.srem("myset", ["Hello", "Foo"]).should eq(2)
              redis.not_nil!.smembers("myset").should eq(["World"])
            end
          else
            pending ":redis is not running: #srem"
          end

          if redis_is_running
            it "#sdiff" do
              redis.not_nil!.del("key1", "key2")
              redis.not_nil!.sadd("key1", "a", "b", "c")
              redis.not_nil!.sadd("key2", "c", "d", "e")
              sort(redis.not_nil!.sdiff("key1", "key2")).should eq(["a", "b"])
            end
          else
            pending ":redis is not running: #sdiff"
          end

          if redis_is_running
            it "#spop" do
              redis.not_nil!.del("myset")
              redis.not_nil!.sadd("myset", "one")
              redis.not_nil!.spop("myset").should eq("one")
              redis.not_nil!.smembers("myset").should eq([] of Redis::RedisValue)
              # Redis 3.0 should have received the "count" argument, but hasn't.
              #
              # redis.not_nil!.sadd("myset", "one", "two")
              # sort(redis.not_nil!.spop("myset", count: 2)).should eq(["one", "two"])

              redis.not_nil!.del("myset")
              redis.not_nil!.spop("myset").should eq(nil)
            end
          else
            pending ":redis is not running: #spop"
          end

          if redis_is_running
            it "#sdiffstore" do
              redis.not_nil!.del("key1", "key2", "destination")
              redis.not_nil!.sadd("key1", "a", "b", "c")
              redis.not_nil!.sadd("key2", "c", "d", "e")
              redis.not_nil!.sdiffstore("destination", "key1", "key2").should eq(2)
              sort(redis.not_nil!.smembers("destination")).should eq(["a", "b"])
            end
          else
            pending ":redis is not running: #sdiffstore"
          end

          if redis_is_running
            it "#sinter" do
              redis.not_nil!.del("key1", "key2")
              redis.not_nil!.sadd("key1", "a", "b", "c")
              redis.not_nil!.sadd("key2", "c", "d", "e")
              redis.not_nil!.sinter("key1", "key2").should eq(["c"])
            end
          else
            pending ":redis is not running: #sinter"
          end

          if redis_is_running
            it "#sinterstore" do
              redis.not_nil!.del("key1", "key2", "destination")
              redis.not_nil!.sadd("key1", "a", "b", "c")
              redis.not_nil!.sadd("key2", "c", "d", "e")
              redis.not_nil!.sinterstore("destination", "key1", "key2").should eq(1)
              redis.not_nil!.smembers("destination").should eq(["c"])
            end
          else
            pending ":redis is not running: #sinterstore"
          end

          if redis_is_running
            it "#sunion" do
              redis.not_nil!.del("key1", "key2")
              redis.not_nil!.sadd("key1", "a", "b")
              redis.not_nil!.sadd("key2", "c", "d")
              sort(redis.not_nil!.sunion("key1", "key2")).should eq(["a", "b", "c", "d"])
            end
          else
            pending ":redis is not running: #sunion"
          end

          if redis_is_running
            it "#sunionstore" do
              redis.not_nil!.del("key1", "key2", "destination")
              redis.not_nil!.sadd("key1", "a", "b")
              redis.not_nil!.sadd("key2", "c", "d")
              redis.not_nil!.sunionstore("destination", "key1", "key2").should eq(4)
              sort(redis.not_nil!.smembers("destination")).should eq(["a", "b", "c", "d"])
            end
          else
            pending ":redis is not running: #sunionstore"
          end

          if redis_is_running
            it "#smove" do
              redis.not_nil!.del("key1", "key2", "destination")
              redis.not_nil!.sadd("key1", "a", "b")
              redis.not_nil!.sadd("key2", "c")
              redis.not_nil!.smove("key1", "key2", "b").should eq(1)
              redis.not_nil!.smembers("key1").should eq(["a"])
              sort(redis.not_nil!.smembers("key2")).should eq(["b", "c"])
            end
          else
            pending ":redis is not running: #smove"
          end

          if redis_is_running
            it "#srandmember" do
              redis.not_nil!.del("key1", "key2", "destination")
              redis.not_nil!.sadd("key1", "a")
              redis.not_nil!.srandmember("key1", 1).should eq(["a"])
            end
          else
            pending ":redis is not running: #srandmember"
          end

          describe "#sscan" do
            if redis_is_running
              it "no options" do
                redis.not_nil!.del("myset")
                redis.not_nil!.sadd("myset", "a", "b")
                new_cursor, keys = redis.not_nil!.sscan("myset", 0)
                new_cursor.should eq("0")
                sort(keys).should eq(["a", "b"])
              end
            else
              pending ":redis is not running: no options"
            end

            if redis_is_running
              it "with match" do
                redis.not_nil!.del("myset")
                redis.not_nil!.sadd("myset", "foo", "bar", "foo2", "foo3")
                _new_cursor, keys = redis.not_nil!.sscan("myset", 0, "foo*", 2)
                keys.is_a?(Array).should be_true
                array(keys).size.should be > 0
              end
            else
              pending ":redis is not running: with match"
            end

            if redis_is_running
              it "with match and count" do
                redis.not_nil!.del("myset")
                redis.not_nil!.sadd("myset", "foo", "bar", "baz")
                new_cursor, keys = redis.not_nil!.sscan("myset", 0, "*a*", 1)
                new_cursor = new_cursor.as(String)
                new_cursor.to_i.should be > 0
                keys.is_a?(Array).should be_true
                # TODO SW: This assertion fails randomly
                # array(keys).size.should be > 0
              end
            else
              pending ":redis is not running: with match and count"
            end

            if redis_is_running
              it "with match and count at once" do
                redis.not_nil!.del("myset")
                redis.not_nil!.sadd("myset", "foo", "bar", "baz")
                new_cursor, keys = redis.not_nil!.sscan("myset", 0, "*a*", 10)
                new_cursor.should eq("0")
                keys.is_a?(Array).should be_true
                array(keys).sort.should eq(["bar", "baz"])
              end
            else
              pending ":redis is not running: with match and count at once"
            end
          end
        end

        describe "hashes" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "#hset / #hget" do
              redis.not_nil!.del("myhash")
              redis.not_nil!.hset("myhash", "a", "434")
              redis.not_nil!.hget("myhash", "a").should eq("434")
              redis.not_nil!.hset("myhash", "b", "435")
              redis.not_nil!.hget("myhash", "b").should eq("435")
            end
          else
            pending ":redis is not running: #hset / #hget"
          end

          if redis_is_running
            it "#hgetall" do
              redis.not_nil!.del("myhash")
              redis.not_nil!.hset("myhash", "a", "123")
              redis.not_nil!.hset("myhash", "b", "456")
              redis.not_nil!.hgetall("myhash").should eq({"a" => "123", "b" => "456"})
              redis.not_nil!.del("myhash")
              redis.not_nil!.hgetall("myhash").should eq({} of String => String)
            end
          else
            pending ":redis is not running: #hgetall"
          end

          if redis_is_running
            it "#hdel" do
              redis.not_nil!.del("myhash")
              redis.not_nil!.hset("myhash", "field1", "foo")
              redis.not_nil!.hdel("myhash", "field1").should eq(1)
              redis.not_nil!.hget("myhash", "field1").should eq(nil)
            end
          else
            pending ":redis is not running: #hdel"
          end

          if redis_is_running
            it "#hexists" do
              redis.not_nil!.del("myhash")
              redis.not_nil!.hset("myhash", "field1", "foo")
              redis.not_nil!.hexists("myhash", "field1").should eq(1)
              redis.not_nil!.hexists("myhash", "field2").should eq(0)
            end
          else
            pending ":redis is not running: #hexists"
          end

          if redis_is_running
            it "#hincrby" do
              redis.not_nil!.del("myhash")
              redis.not_nil!.hset("myhash", "field1", "1")
              redis.not_nil!.hincrby("myhash", "field1", "3").should eq(4)
            end
          else
            pending ":redis is not running: #hincrby"
          end

          if redis_is_running
            it "#hincrbyfloat" do
              redis.not_nil!.del("myhash")
              redis.not_nil!.hset("myhash", "field1", "10.50")
              redis.not_nil!.hincrbyfloat("myhash", "field1", "0.1").should eq("10.6")
            end
          else
            pending ":redis is not running: #hincrbyfloat"
          end

          if redis_is_running
            it "#hkeys" do
              redis.not_nil!.del("myhash")
              redis.not_nil!.hset("myhash", "field1", "1")
              redis.not_nil!.hset("myhash", "field2", "2")
              redis.not_nil!.hkeys("myhash").should eq(["field1", "field2"])
            end
          else
            pending ":redis is not running: #hkeys"
          end

          if redis_is_running
            it "#hlen" do
              redis.not_nil!.del("myhash")
              redis.not_nil!.hset("myhash", "field1", "1")
              redis.not_nil!.hset("myhash", "field2", "2")
              redis.not_nil!.hlen("myhash").should eq(2)
            end
          else
            pending ":redis is not running: #hlen"
          end

          if redis_is_running
            it "#hmget" do
              redis.not_nil!.del("myhash")
              redis.not_nil!.hset("myhash", "a", "123")
              redis.not_nil!.hset("myhash", "b", "456")
              redis.not_nil!.hmget("myhash", "a", "b").should eq(["123", "456"])
              redis.not_nil!.hmget("myhash", ["a", "b"]).should eq(["123", "456"])
            end
          else
            pending ":redis is not running: #hmget"
          end

          if redis_is_running
            it "#hmset" do
              redis.not_nil!.del("myhash")
              redis.not_nil!.hmset("myhash", {"field1": "a", "field2": 2})
              redis.not_nil!.hget("myhash", "field1").should eq("a")
              redis.not_nil!.hget("myhash", "field2").should eq("2")
            end
          else
            pending ":redis is not running: #hmset"
          end

          describe "#hscan" do
            if redis_is_running
              redis = namespace ? Redis.new(namespace: namespace) : Redis.new
            end

            if redis_is_running
              it "no options" do
                redis.not_nil!.del("myhash")
                redis.not_nil!.hmset("myhash", {"field1": "a", "field2": "b"})
                new_cursor, keys = redis.not_nil!.hscan("myhash", 0)
                new_cursor.should eq("0")
                keys.should eq({"field1" => "a", "field2" => "b"})
              end
            else
              pending ":redis is not running: #hscan"
            end

            if redis_is_running
              it "with match" do
                redis.not_nil!.del("myhash")
                redis.not_nil!.hmset("myhash", {"foo": "a", "bar": "b"})
                new_cursor, keys = redis.not_nil!.hscan("myhash", 0, "f*")
                new_cursor.should eq("0")
                keys.should eq({"foo" => "a"})
              end
            else
              pending ":redis is not running: #hscan"
            end

            # pending: hscan doesn't handle COUNT strictly
            # it "#hscan with match and count" do
            # end

            if redis_is_running
              it "with match and count at once" do
                redis.not_nil!.del("myhash")
                redis.not_nil!.hmset("myhash", {"foo": "a", "bar": "b", "baz": "c"})
                new_cursor, keys = redis.not_nil!.hscan("myhash", 0, "*a*", 1024)
                new_cursor.should eq("0")
                keys.keys.sort!.should eq(["bar", "baz"])
              end
            else
              pending ":redis is not running: #hscan"
            end
          end

          if redis_is_running
            it "#hsetnx" do
              redis.not_nil!.del("myhash")
              redis.not_nil!.hsetnx("myhash", "foo", "setnxed").should eq(1)
              redis.not_nil!.hget("myhash", "foo").should eq("setnxed")
              redis.not_nil!.hsetnx("myhash", "foo", "setnxed2").should eq(0)
              redis.not_nil!.hget("myhash", "foo").should eq("setnxed")
            end
          else
            pending ":redis is not running: #hsetnx"
          end

          if redis_is_running
            it "#hvals" do
              redis.not_nil!.del("myhash")
              redis.not_nil!.hset("myhash", "a", "123")
              redis.not_nil!.hset("myhash", "b", "456")
              redis.not_nil!.hvals("myhash").should eq(["123", "456"])
            end
          else
            pending ":redis is not running: #hvals"
          end
        end

        describe "sorted sets" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "#zadd / zrange" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one").should eq(1)
              redis.not_nil!.zadd("myzset", [1, "uno"]).should eq(1)
              redis.not_nil!.zadd("myzset", 2, "two", 3, "three").should eq(2)
              redis.not_nil!.zrange("myzset", 0, -1, with_scores: true).should eq(["one", "1", "uno", "1", "two", "2", "three", "3"])
            end
          else
            pending ":redis is not running: #zadd / zrange"
          end

          if redis_is_running
            it "#zadd / zrange with xx" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one").should eq(1)
              redis.not_nil!.zadd("myzset", 11, "one", xx: true).should eq(0)
              redis.not_nil!.zadd("myzset", 2, "two", xx: true).should eq(0)
              redis.not_nil!.zadd("myzset", 3, "three", xx: false).should eq(1)
              redis.not_nil!.zrange("myzset", 0, -1, with_scores: true).should eq(["three", "3", "one", "11"])
            end
          else
            pending ":redis is not running: #zadd / zrange with xx"
          end

          if redis_is_running
            it "#zadd / zrange with nx" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one").should eq(1)
              redis.not_nil!.zadd("myzset", 11, "one", nx: true).should eq(0)
              redis.not_nil!.zadd("myzset", 2, "two", nx: true).should eq(1)
              redis.not_nil!.zadd("myzset", 3, "three", nx: false).should eq(1)
              redis.not_nil!.zrange("myzset", 0, -1, with_scores: true).should eq(["one", "1", "two", "2", "three", "3"])
            end
          else
            pending ":redis is not running: #zadd / zrange with nx"
          end

          if redis_is_running
            it "#zadd / zrange with ch" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one", ch: true).should eq(1)
              redis.not_nil!.zadd("myzset", 11, "one", ch: true).should eq(1)
              redis.not_nil!.zadd("myzset", 2, "two", ch: true).should eq(1)
              redis.not_nil!.zadd("myzset", 3, "three", ch: false).should eq(1)
              redis.not_nil!.zrange("myzset", 0, -1, with_scores: true).should eq(["two", "2", "three", "3", "one", "11"])
            end
          else
            pending ":redis is not running: #zadd / zrange with ch"
          end

          if redis_is_running
            it "#zadd / zrange with incr" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one", incr: true).should eq("1")
              redis.not_nil!.zadd("myzset", 11, "one", incr: true).should eq("12")
              redis.not_nil!.zrange("myzset", 0, -1, with_scores: true).should eq(["one", "12"])
            end
          else
            pending ":redis is not running: #zadd / zrange with incr"
          end

          if redis_is_running
            it "#zrangebylex" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 0, "a", 0, "b", 0, "c", 0, "d", 0, "e", 0, "f", 0, "g")
              redis.not_nil!.zrangebylex("myzset", "-", "[c").should eq(["a", "b", "c"])
              redis.not_nil!.zrangebylex("myzset", "-", "(c").should eq(["a", "b"])
              redis.not_nil!.zrangebylex("myzset", "[aaa", "(g").should eq(["b", "c", "d", "e", "f"])
              redis.not_nil!.zrangebylex("myzset", "[aaa", "(g", limit: [0, 4]).should eq(["b", "c", "d", "e"])
            end
          else
            pending ":redis is not running: #zrangebylex"
          end

          if redis_is_running
            it "#zrangebyscore" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one", 2, "two", 3, "three")
              redis.not_nil!.zrangebyscore("myzset", "-inf", "+inf").should eq(["one", "two", "three"])
              redis.not_nil!.zrangebyscore("myzset", "-inf", "+inf", limit: [0, 2]).should eq(["one", "two"])
            end
          else
            pending ":redis is not running: #zrangebyscore"
          end

          if redis_is_running
            it "#zrevrange" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one", 2, "two", 3, "three")
              redis.not_nil!.zrevrange("myzset", 0, -1).should eq(["three", "two", "one"])
              redis.not_nil!.zrevrange("myzset", 2, 3).should eq(["one"])
              redis.not_nil!.zrevrange("myzset", -2, -1).should eq(["two", "one"])
            end
          else
            pending ":redis is not running: #zrevrange"
          end

          if redis_is_running
            it "#zrevrangebylex" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 0, "a", 0, "b", 0, "c", 0, "d", 0, "e", 0, "f", 0, "g")
              redis.not_nil!.zrevrangebylex("myzset", "[c", "-").should eq(["c", "b", "a"])
              redis.not_nil!.zrevrangebylex("myzset", "(c", "-").should eq(["b", "a"])
              redis.not_nil!.zrevrangebylex("myzset", "(g", "[aaa").should eq(["f", "e", "d", "c", "b"])
              redis.not_nil!.zrevrangebylex("myzset", "+", "-", limit: [1, 1]).should eq(["f"])
            end
          else
            pending ":redis is not running: #zrevrangebylex"
          end

          if redis_is_running
            it "#zrevrangebyscore" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one", 2, "two", 3, "three")
              redis.not_nil!.zrevrangebyscore("myzset", "+inf", "-inf").should eq(["three", "two", "one"])
              redis.not_nil!.zrevrangebyscore("myzset", "+inf", "-inf", limit: [0, 2]).should eq(["three", "two"])
            end
          else
            pending ":redis is not running: #zrevrangebyscore"
          end

          if redis_is_running
            it "#zscore" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 2, "two")
              redis.not_nil!.zscore("myzset", "two").should eq("2")
            end
          else
            pending ":redis is not running: #zscore"
          end

          if redis_is_running
            it "#zcard" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 2, "two", 3, "three")
              redis.not_nil!.zcard("myzset").should eq(2)
            end
          else
            pending ":redis is not running: #zcard"
          end

          if redis_is_running
            it "#zcount" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one", 2, "two", 3, "three")
              redis.not_nil!.zcount("myzset", "-inf", "+inf").should eq(3)
              redis.not_nil!.zcount("myzset", "(1", "3").should eq(2)
            end
          else
            pending ":redis is not running: #zcount"
          end

          if redis_is_running
            it "#zlexcount" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 0, "a", 0, "b", 0, "c", 0, "d", 0, "e", 0, "f", 0, "g")
              redis.not_nil!.zlexcount("myzset", "-", "+").should eq(7)
              redis.not_nil!.zlexcount("myzset", "[b", "[f").should eq(5)
            end
          else
            pending ":redis is not running: #zlexcount"
          end

          if redis_is_running
            it "#zrank" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one", 2, "two", 3, "three")
              redis.not_nil!.zrank("myzset", "one").should eq(0)
              redis.not_nil!.zrank("myzset", "three").should eq(2)
              redis.not_nil!.zrank("myzset", "four").should eq(nil)
            end
          else
            pending ":redis is not running: #zrank"
          end

          describe "zscan" do
            if redis_is_running
              it "no options" do
                redis.not_nil!.del("myset")
                redis.not_nil!.zadd("myzset", 1, "one", 2, "two", 3, "three")
                new_cursor, keys = redis.not_nil!.zscan("myzset", 0)
                new_cursor.should eq("0")
                keys.should eq(["one", "1", "two", "2", "three", "3"])
              end
            else
              pending ":redis is not running: no options"
            end

            if redis_is_running
              it "with match" do
                redis.not_nil!.del("myzset")
                redis.not_nil!.zadd("myzset", 1, "one", 2, "two", 3, "three")
                new_cursor, keys = redis.not_nil!.zscan("myzset", 0, "t*")
                new_cursor.should eq("0")
                keys.is_a?(Array).should be_true
                # extract odd elements for keys because zscan returns (key, val) as a single list
                keys = array(keys).in_groups_of(2).map(&.first.not_nil!)
                keys.should eq(["two", "three"])
              end
            else
              pending ":redis is not running: with match"
            end

            # pending: zscan doesn't handle COUNT strictly
            # it "#zscan with match and count" do
            # end

            if redis_is_running
              it "with match and count at once" do
                redis.not_nil!.del("myzset")
                redis.not_nil!.zadd("myzset", 1, "one", 2, "two", 3, "three")
                new_cursor, keys = redis.not_nil!.zscan("myzset", 0, "t*", 1024)
                new_cursor.should eq("0")
                keys.is_a?(Array).should be_true
                # extract odd elements for keys because zscan returns (key, val) as a single list
                keys = array(keys).in_groups_of(2).map(&.first.not_nil!)
                keys.should eq(["two", "three"])
              end
            else
              pending ":redis is not running: with match and count at once"
            end
          end

          if redis_is_running
            it "#zrevrank" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one", 2, "two", 3, "three")
              redis.not_nil!.zrevrank("myzset", "one").should eq(2)
              redis.not_nil!.zrevrank("myzset", "three").should eq(0)
              redis.not_nil!.zrevrank("myzset", "four").should eq(nil)
            end
          else
            pending ":redis is not running: #zrevrank"
          end

          if redis_is_running
            it "#zincrby" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one")
              redis.not_nil!.zincrby("myzset", 2, "one").should eq("3")
              redis.not_nil!.zrange("myzset", 0, -1, with_scores: true).should eq(["one", "3"])
            end
          else
            pending ":redis is not running: #zincrby"
          end

          if redis_is_running
            it "#zrem" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one", 2, "two", 3, "three")
              redis.not_nil!.zrem("myzset", "two").should eq(1)
              redis.not_nil!.zcard("myzset").should eq(2)
            end
          else
            pending ":redis is not running: #zrem"
          end

          if redis_is_running
            it "#zremrangebylex" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 0, "aaaa", 0, "b", 0, "c", 0, "d", 0, "e")
              redis.not_nil!.zadd("myzset", 0, "foo", 0, "zap", 0, "zip", 0, "ALPHA", 0, "alpha")
              redis.not_nil!.zremrangebylex("myzset", "[alpha", "[omega")
              redis.not_nil!.zrange("myzset", 0, -1).should eq(["ALPHA", "aaaa", "zap", "zip"])
            end
          else
            pending ":redis is not running: #zremrangebylex"
          end

          if redis_is_running
            it "#zremrangebyrank" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one", 2, "two", 3, "three")
              redis.not_nil!.zremrangebyrank("myzset", 0, 1).should eq(2)
              redis.not_nil!.zrange("myzset", 0, -1, with_scores: true).should eq(["three", "3"])
            end
          else
            pending ":redis is not running: #zremrangebyrank"
          end

          if redis_is_running
            it "#zremrangebyscore" do
              redis.not_nil!.del("myzset")
              redis.not_nil!.zadd("myzset", 1, "one", 2, "two", 3, "three")
              redis.not_nil!.zremrangebyscore("myzset", "-inf", "(2").should eq(1)
              redis.not_nil!.zrange("myzset", 0, -1, with_scores: true).should eq(["two", "2", "three", "3"])
            end
          else
            pending ":redis is not running: #zremrangebyscore"
          end

          if redis_is_running
            it "#zinterstore" do
              redis.not_nil!.del("zset1", "zset2", "zset3")
              redis.not_nil!.zadd("zset1", 1, "one", 2, "two")
              redis.not_nil!.zadd("zset2", 1, "one", 2, "two", 3, "three")
              redis.not_nil!.zinterstore("zset3", ["zset1", "zset2"], weights: [2, 3]).should eq(2)
              redis.not_nil!.zrange("zset3", 0, -1, with_scores: true).should eq(["one", "5", "two", "10"])
            end
          else
            pending ":redis is not running: #zinterstore"
          end

          if redis_is_running
            it "#zunionstore" do
              redis.not_nil!.del("zset1", "zset2", "zset3")
              redis.not_nil!.zadd("zset1", 1, "one", 2, "two")
              redis.not_nil!.zadd("zset2", 1, "one", 2, "two", 3, "three")
              redis.not_nil!.zunionstore("zset3", ["zset1", "zset2"], weights: [2, 3]).should eq(3)
              redis.not_nil!.zrange("zset3", 0, -1, with_scores: true).should eq(["one", "5", "three", "9", "two", "10"])
            end
          else
            pending ":redis is not running: #zunionstore"
          end
        end

        describe "#pipelined" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "executes the commands in the block and returns the results" do
              futures = [] of Redis::Future
              results = redis.not_nil!.pipelined do |pipeline|
                pipeline.set("foo", "new value")
                futures << pipeline.get("foo")
              end
              results[1].should eq("new value")
              futures[0].value.should eq("new value")

              _client_traces, server_traces = FindJson.from_io(memory)
              server_traces[0]["spans"][0]["name"].should eq "Redis: SET #{[namespace, "foo"].compact.join("::")}"
              server_traces[2]["spans"][0]["name"].should eq "Redis::Future#value="
              server_traces[2]["spans"][0]["attributes"]["db.redis.future.value"].should eq "OK"
              server_traces[2]["spans"][0]["parentSpanId"].should eq server_traces[0]["spans"][0]["spanId"]
              server_traces[3]["spans"][0]["attributes"]["db.redis.future.value"].should eq "new value"
              server_traces[3]["spans"][0]["parentSpanId"].should eq server_traces[1]["spans"][0]["spanId"]
            end
          else
            pending ":redis is not running: executes the commands in the block and returns the results"
          end

          if redis_is_running
            it "raises an exception if we call methods on the Redis object" do
              redis.not_nil!.pipelined do |_pipeline|
                expect_raises Redis::Error do
                  redis.not_nil!.set("foo", "bar")
                end
              end
            end
          else
            pending ":redis is not running: raises an exception if we call methods on the Redis object"
          end

          if redis_is_running
            it "work with hgetall" do
              redis.not_nil!.del("myhash")
              redis.not_nil!.hset("myhash", "a", "123")
              redis.not_nil!.hset("myhash", "b", "456")

              h = redis.not_nil!.pipelined do |pipeline|
                pipeline.exists("myhash")
                pipeline.hgetall("myhash")
              end

              h.should eq([1, ["a", "123", "b", "456"]])
            end
          else
            pending ":redis is not running: work with hgetall"
          end
        end

        describe "hyperloglog" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "#pfadd / #pfcount" do
              redis.not_nil!.del("hll")
              redis.not_nil!.pfadd("hll", "a", "b", "c", "d", "e", "f", "g").should eq(1)
              redis.not_nil!.pfcount("hll").should eq(7)
            end
          else
            pending ":redis is not running: #pfadd / #pfcount"
          end

          if redis_is_running
            it "#pfmerge" do
              redis.not_nil!.del("hll1", "hll2", "hll3")
              redis.not_nil!.pfadd("hll1", "foo", "bar", "zap", "a")
              redis.not_nil!.pfadd("hll2", "a", "b", "c", "foo")
              redis.not_nil!.pfmerge("hll3", "hll1", "hll2").should eq("OK")
              redis.not_nil!.pfcount("hll3").should eq(6)
            end
          else
            pending ":redis is not running: #pfmerge"
          end
        end

        describe "#info" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "returns server data" do
              x = redis.not_nil!.info
              x.size.should be >= 70

              x = redis.not_nil!.info("cpu")
              (4..8).should contain(x.size)

              redis.not_nil!.info["redis_version"].should_not be_nil
            end
          else
            pending ":redis is not running: returns server data"
          end
        end

        describe "#multi" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "executes the commands in the block and returns the results" do
              futures = [] of Redis::Future
              results = redis.not_nil!.multi do |multi|
                multi.set("foo", "new value")
                futures << multi.get("foo")
              end
              results[1].should eq("new value")
              # future.not_nil!
              futures[0].value.should eq("new value")
            end
          else
            pending ":redis is not running: executes the commands in the block and returns the results"
          end

          if redis_is_running
            it "does not execute the commands in the block upon #discard" do
              redis.not_nil!.set("foo", "initial value")
              results = redis.not_nil!.multi do |multi|
                multi.set("foo", "new value")
                multi.discard
              end
              redis.not_nil!.get("foo").should eq("initial value")
              results.should eq([] of Redis::RedisValue)
            end
          else
            pending ":redis is not running: does not execute the commands in the block upon #discard"
          end

          if redis_is_running
            it "performs optimistic locking with #watch" do
              redis.not_nil!.set("foo", "1")
              current_value = redis.not_nil!.get("foo").not_nil!
              redis.not_nil!.watch("foo")
              redis.not_nil!.multi do |multi|
                other_redis = namespace ? Redis.new(namespace: namespace) : Redis.new
                other_redis.not_nil!.set("foo", "value set by other client")
                multi.set("foo", current_value + "2")
              end
              redis.not_nil!.get("foo").should eq("value set by other client")
            end
          else
            pending ":redis is not running: performs optimistic locking with #watch"
          end

          if redis_is_running
            it "#watch" do
              redis.not_nil!.set("foo", "1")
              redis.not_nil!.watch("foo")
              redis.not_nil!.unwatch
            end
          else
            pending ":redis is not running: #watch"
          end

          if redis_is_running
            it "raises an exception if we call methods on the Redis object" do
              redis.not_nil!.multi do |_multi|
                expect_raises Redis::Error do
                  redis.not_nil!.set("foo", "bar")
                end
              end
            end
          else
            pending ":redis is not running: raises an exception if we call methods on the Redis object"
          end

          if redis_is_running
            it "zadd works in multi" do
              redis.not_nil!.del("myzset")

              redis.not_nil!.multi do |multi|
                multi.zadd("myzset", 1.0, "one")
                multi.zadd("myzset", [1, "uno"])
                multi.zadd("myzset", 2, "two", 3, "three")
              end

              redis.not_nil!.zrange("myzset", 0, -1, with_scores: true).should eq(["one", "1", "uno", "1", "two", "2", "three", "3"])
            end
          else
            pending ":redis is not running: zadd works in multi"
          end
        end

        describe "LUA scripting" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          describe "#eval" do
            if redis_is_running
              it "executes the LUA script" do
                keys = ["key1", "key2"] of Redis::RedisValue
                args = ["first", "second"] of Redis::RedisValue
                result = redis.not_nil!.eval("return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}", keys, args)
                result.should eq(["key1", "key2", "first", "second"])
              end
            else
              pending ":redis is not running: executes the LUA script"
            end

            if redis_is_running
              it "handles different return types" do
                keys = ["key1", "key2"] of Redis::RedisValue
                args = ["first", "second"] of Redis::RedisValue
                result = redis.not_nil!.eval("return KEYS[1]", keys, args)
                result.should eq("key1")
              end
            else
              pending ":redis is not running: handles different return types"
            end
          end

          describe "#script_load / #eval_sha" do
            if redis_is_running
              it "registers a LUA script and calls it" do
                sha1 = redis.not_nil!.script_load("return {KEYS[1],ARGV[1]}")
                keys = ["key1", "key2"] of Redis::RedisValue
                args = ["first", "second"] of Redis::RedisValue
                result = redis.not_nil!.evalsha(sha1, keys, args)
                result.should eq(["key1", "first"])
              end
            else
              pending ":redis is not running: registers a LUA script and calls it"
            end

            if redis_is_running
              it "handles different return types" do
                sha1 = redis.not_nil!.script_load("return KEYS[1]")
                keys = ["key1", "key2"] of Redis::RedisValue
                args = ["first", "second"] of Redis::RedisValue
                result = redis.not_nil!.evalsha(sha1, keys, args)
                result.should eq("key1")
              end
            else
              pending ":redis is not running: handles different return types"
            end
          end

          describe "#script_kill" do
            if redis_is_running
              it "kills the currently running LUA script" do
                begin
                  redis.not_nil!.script_kill
                rescue Redis::Error
                end
              end
            else
              pending ":redis is not running: kills the currently running LUA script"
            end
          end

          describe "#script_exists" do
            if redis_is_running
              it "checks if the given LUA scripts exist" do
                sha1 = redis.not_nil!.script_load("return 10")
                result = redis.not_nil!.script_exists([sha1, "fffffffffffffff"])
                result.should eq([1, 0])
              end
            else
              pending ":redis is not running: checks if the given LUA scripts exist"
            end
          end

          describe "#script_flush" do
            if redis_is_running
              it "flushes the LUA script cache" do
                sha1 = redis.not_nil!.script_load("return 10")
                redis.not_nil!.script_flush
                redis.not_nil!.script_exists([sha1]).should eq([0])
              end
            else
              pending ":redis is not running: flushes the LUA script cache"
            end
          end
        end

        describe "#type" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "returns a value's type as a string" do
              redis.not_nil!.set("foo", 3)
              redis.not_nil!.type("foo").should eq("string")
            end
          else
            pending ":redis is not running: returns a value's type as a string"
          end
        end

        describe "expiry" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "#expire" do
              redis.not_nil!.set("temp", "3")
              redis.not_nil!.expire("temp", 2).should eq(1)
            end
          else
            pending ":redis is not running: #expire"
          end

          if redis_is_running
            it "#expireat" do
              redis.not_nil!.set("temp", "3")
              redis.not_nil!.expireat("temp", 1555555555005).should eq(1)
              redis.not_nil!.ttl("temp").should be > 3000
            end
          else
            pending ":redis is not running: #expireat"
          end

          if redis_is_running
            it "#ttl" do
              redis.not_nil!.set("temp", "9")
              redis.not_nil!.ttl("temp").should eq(-1)
              redis.not_nil!.expire("temp", 3)
              redis.not_nil!.ttl("temp").should eq(3)
            end
          else
            pending ":redis is not running: #ttl"
          end

          if redis_is_running
            it "#pexpire" do
              redis.not_nil!.set("temp", "3")
              redis.not_nil!.pexpire("temp", 1000).should eq(1)
            end
          else
            pending ":redis is not running: #pexpire"
          end

          if redis_is_running
            it "#pexpireat" do
              redis.not_nil!.set("temp", "3")
              timeout = Time.utc(2029, 2, 15, 10, 20, 30)
              redis.not_nil!.pexpireat("temp", timeout.to_unix_ms).should eq(1)
              redis.not_nil!.pttl("temp").should be > 2990
            end
          else
            pending ":redis is not running: #pexpireat"
          end

          if redis_is_running
            it "#pttl" do
              redis.not_nil!.set("temp", "9")
              redis.not_nil!.pttl("temp").should eq(-1)
              redis.not_nil!.pexpire("temp", 3000)
              redis.not_nil!.pttl("temp").should be > 2990
            end
          else
            pending ":redis is not running: #pttl"
          end

          if redis_is_running
            it "#persist" do
              redis.not_nil!.set("temp", "9")
              redis.not_nil!.expire("temp", 3)
              redis.not_nil!.ttl("temp").should eq(3)
              redis.not_nil!.persist("temp")
              redis.not_nil!.ttl("temp").should eq(-1)
            end
          else
            pending ":redis is not running: #persist"
          end
        end

        describe "publish / subscribe" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "#publish" do
              redis.not_nil!.publish("mychannel", "my message")
            end
          else
            pending ":redis is not running: #publish"
          end

          if redis_is_running
            it "#subscribe / #unsubscribe" do
              callbacks_received = [] of String
              redis.not_nil!.subscribe("mychannel") do |on|
                on.subscribe do |channel, subscriptions|
                  channel.should eq("mychannel")
                  subscriptions.should eq(1)
                  callbacks_received << "subscribe"

                  # Send a message to ourselves so that we can test the other callbacks.
                  # We need a second connection to do so.
                  Redis.open do |other_redis|
                    other_redis.not_nil!.publish("mychannel", "just talking to myself")
                  end
                end

                on.message do |channel, message|
                  channel.should eq("mychannel")
                  message.should eq("just talking to myself")
                  callbacks_received << "message"

                  # Great, we are done.
                  redis.not_nil!.unsubscribe("mychannel")
                end

                on.unsubscribe do |channel, subscriptions|
                  channel.should eq("mychannel")
                  subscriptions.should eq(0)
                  callbacks_received << "unsubscribe"
                end
              end

              callbacks_received.should eq(["subscribe", "message", "unsubscribe"])
            end
          else
            pending ":redis is not running: #subscribe / #unsubscribe"
          end

          if redis_is_running
            it "can be used after #unsubscribe" do
              redis.not_nil!.subscribe("mychannel") do |on|
                on.subscribe do |c, _s|
                  redis.not_nil!.unsubscribe(c)
                end
              end
              redis.not_nil!.set("temp", "temp1")
              redis.not_nil!.get("temp").should eq "temp1"
            end
          else
            pending ":redis is not running: can be used after #unsubscribe"
          end

          if redis_is_running
            it "use ping in #subscribe" do
              redis.not_nil!.del("mychannel")
              res = [] of String

              spawn do
                redis.not_nil!.subscribe("mychannel") do |on|
                  on.message do |_channel, message|
                    res << message
                    res << redis.not_nil!.ping
                    redis.not_nil!.unsubscribe("mychannel") if res.size >= 4
                  end
                end
              end

              Redis.new.publish("mychannel", "11")
              Redis.new.publish("mychannel", "22")

              sleep 0.1
              res.should eq ["11", "pong", "22", "pong"]
            end
          else
            pending ":redis is not running: use ping in #subscribe"
          end
        end

        describe "punsubscribe" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "#psubscribe / #punsubscribe" do
              callbacks_received = [] of String

              redis.not_nil!.psubscribe("otherchan*") do |on|
                on.psubscribe do |channel_pattern, subscriptions|
                  channel_pattern.should eq("otherchan*")
                  subscriptions.should eq(1)
                  callbacks_received << "psubscribe"

                  # Send a message to ourselves so that we can test the other callbacks.
                  # We need a second connection to do so.
                  Redis.open do |other_redis|
                    other_redis.not_nil!.publish("otherchannel", "hello subscriber")
                  end
                end

                on.pmessage do |channel_pattern, channel, message|
                  channel_pattern.should eq("otherchan*")
                  channel.should eq("otherchannel")
                  message.should eq("hello subscriber")
                  callbacks_received << "pmessage"

                  # Great, we are done.
                  redis.not_nil!.punsubscribe("otherchan*")
                end

                on.punsubscribe do |channel_pattern, subscriptions|
                  channel_pattern.should eq("otherchan*")
                  subscriptions.should eq(0)
                  callbacks_received << "punsubscribe"
                end
              end

              callbacks_received.should eq(["psubscribe", "pmessage", "punsubscribe"])
            end
          else
            pending ":redis is not running: #psubscribe / #punsubscribe"
          end
        end

        describe "OBJECT commands" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "#object_refcount" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.rpush("mylist", "Hello", "World")
              redis.not_nil!.object_refcount("mylist").should eq(1)
            end
          else
            pending ":redis is not running: #object_refcount"
          end

          if redis_is_running
            it "#object_encoding" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.rpush("mylist", "Hello", "World")
              redis.not_nil!.object_encoding("mylist").should eq("quicklist")
            end
          else
            pending ":redis is not running: #object_encoding"
          end

          if redis_is_running
            it "#object_idletime" do
              redis.not_nil!.del("mylist")
              redis.not_nil!.rpush("mylist", "Hello", "World")
              redis.not_nil!.object_idletime("mylist").should eq(0)
            end
          else
            pending ":redis is not running: #object_idletime"
          end
        end

        describe "GEO commands" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "#geoadd" do
              redis.not_nil!.geoadd("Nebraska", -96.8308123, 40.8005243, "Lincoln").should eq(1)
              redis.not_nil!.geoadd("Nebraska", -96.3614327, 41.2915193, "Omaha").should eq(1)
            end
          else
            pending ":redis is not running: #geoadd"
          end

          if redis_is_running
            it "#geodist" do
              redis.not_nil!.geodist("Nebraska", "Lincoln", "Omaha", "mi").should eq("41.8340")
            end
          else
            pending ":redis is not running: #geodist"
          end

          if redis_is_running
            it "#geohash" do
              geohash = redis.not_nil!.geohash("Nebraska", "Lincoln", "Omaha")
              geohash.should eq(["9z70he9bq80", "9z76zhzsxc0"])
            end
          else
            pending ":redis is not running: #geohash"
          end

          if redis_is_running
            it "#geopos" do
              pos = redis.not_nil!.geopos("Nebraska", "Lincoln")
              pos.size.should eq(1)
              pos[0].as(Array(Redis::RedisValue)).size.should eq(2)
            end
          else
            pending ":redis is not running: #geopos"
          end

          if redis_is_running
            it "#georadius" do
              results = redis.not_nil!.georadius("Nebraska", -96.8308123, 40.8005243, 100, "mi")
              results.size.should eq(2)
              results.includes?("Lincoln").should be_true
              results.includes?("Omaha").should be_true
            end
          else
            pending ":redis is not running: #georadius"
          end

          if redis_is_running
            it "#georadiusbymember" do
              results = redis.not_nil!.georadiusbymember("Nebraska", "Lincoln", 100, "mi")
              results.size.should eq(2)
              results.includes?("Lincoln").should be_true
              results.includes?("Omaha").should be_true
            end
          else
            pending ":redis is not running: #georadiusbymember"
          end
        end

        describe "large values" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "sends and receives a large value correctly" do
              redis.not_nil!.del("foo")
              large_value = "0123456789" * 100_000 # 1 MB
              redis.not_nil!.set("foo", large_value)
              redis.not_nil!.get("foo").should eq(large_value)
            end
          else
            pending ":redis is not running: large values"
          end
        end

        describe "regression on #keys: compile time error" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          # https://github.com/stefanwille/crystal-redis/issues/100
          if redis_is_running
            it "del + key" do
              redis.not_nil!.set("namespaced::key", 2)
              redis.not_nil!.keys("namespaced::*").each { |key| redis.not_nil!.del(key) }
              redis.not_nil!.keys("namespaced::*").size.should eq 0

              redis.not_nil!.del("namespaced::key") # check that this also compile
            end
          else
            pending ":redis is not running: regression on #keys: compile time error"
          end

          if redis_is_running
            it "del + keys" do
              redis.not_nil!.set("namespaced::key", 2)
              keys = redis.not_nil!.keys("namespaced::*")
              redis.not_nil!.del(keys)
              redis.not_nil!.keys("namespaced::*").size.should eq 0

              redis.not_nil!.del(["namespaced::key"]) # check that this also compile
            end
          else
            pending ":redis is not running: regression on #keys: compile time error"
          end
        end

        context "namespace" do
          if redis_is_running
            redis = namespace ? Redis.new(namespace: namespace) : Redis.new
          end

          if redis_is_running
            it "with namespace" do
              r1 = Redis.new(namespace: "my_namespace")
              r2 = Redis.new
              r3 = Redis.new(namespace: "")
              r2.del("foo")
              r2.del("my_namespace::foo")

              redis.not_nil!.set("foo", "abc")

              if namespace
                r1.get("foo").should eq "abc"
                r2.get("foo").should eq nil
                r2.get("my_namespace::foo").should eq "abc"
                r3.get("foo").should eq nil
                r3.get("my_namespace::foo").should eq "abc"
              else
                r1.get("foo").should eq nil
                r2.get("foo").should eq "abc"
                r2.get("my_namespace::foo").should eq nil
                r3.get("foo").should eq "abc"
                r3.get("my_namespace::foo").should eq nil
              end
            end
          else
            pending ":redis is not running: namespace"
          end
        end
      end
    end

    describe "#flush" do
      if redis_is_running
        it "flushdb" do
          Redis.new.flushdb.should eq("OK")
        end
      else
        pending ":redis is not running: flush"
      end

      if redis_is_running
        it "flushall" do
          Redis.new.flushall.should eq("OK")
        end
      else
        pending ":redis is not running: flush"
      end
    end

    describe "reconnect option: after losing the connection" do
      describe "when true" do
        if redis_is_running
          it "reconnects" do
            redis = Redis.new(reconnect: true)
            redis.not_nil!.close
            redis.not_nil!.ping.should eq("PONG")
          end
        else
          pending ":redis is not running: reconnect"
        end

        if redis_is_running
          it "reconnects for #pipelined" do
            redis = Redis.new(reconnect: true)
            redis.not_nil!.close
            ping_future : Redis::Future? = nil
            redis.not_nil!.pipelined do |api|
              ping_future = api.ping
            end
            ping_future.not_nil!.value.should eq("PONG")
          end
        else
          pending ":redis is not running: reconnect"
        end

        if redis_is_running
          it "reconnects for #multi" do
            redis = Redis.new(reconnect: true)
            redis.not_nil!.close
            ping_future : Redis::Future? = nil
            redis.not_nil!.multi do |api|
              ping_future = api.ping
            end
            ping_future.not_nil!.value.should eq("PONG")
          end
        else
          pending ":redis is not running: reconnect"
        end
      end

      describe "when false" do
        if redis_is_running
          it "raises a helpful exception" do
            redis = Redis.new(reconnect: false)
            redis.not_nil!.close
            expect_raises(Redis::ConnectionLostError, "Not connected to Redis server and reconnect=false") do
              redis.not_nil!.ping
            end
          end
        else
          pending ":redis is not running: reconnect"
        end
      end
    end
  end
end
