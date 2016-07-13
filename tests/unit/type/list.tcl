start_server {
    tags {"list"}
} {
    source "tests/unit/type/list-common.tcl"

    test {LPUSH, RPUSH, LLENGTH, LINDEX, LPOP - ziplist} {
        # first lpush then rpush
        assert_equal 1 [r lpush myziplist1 aa]
        assert_equal 2 [r rpush myziplist1 bb]
        assert_equal 3 [r rpush myziplist1 cc]
        assert_equal 3 [r llen myziplist1]
        assert_equal aa [r lindex myziplist1 0]
        assert_equal bb [r lindex myziplist1 1]
        assert_equal cc [r lindex myziplist1 2]
        assert_equal {} [r lindex myziplist2 3]
        assert_equal cc [r rpop myziplist1]
        assert_equal aa [r lpop myziplist1]
        # assert_encoding quicklist myziplist1

        # first rpush then lpush
        assert_equal 1 [r rpush myziplist2 a]
        assert_equal 2 [r lpush myziplist2 b]
        assert_equal 3 [r lpush myziplist2 c]
        assert_equal 3 [r llen myziplist2]
        assert_equal c [r lindex myziplist2 0]
        assert_equal b [r lindex myziplist2 1]
        assert_equal a [r lindex myziplist2 2]
        assert_equal {} [r lindex myziplist2 3]
        assert_equal a [r rpop myziplist2]
        assert_equal c [r lpop myziplist2]
        # assert_encoding quicklist myziplist2
    }

    test {LPUSH, RPUSH, LLENGTH, LINDEX, LPOP - regular list} {
        # first lpush then rpush
        assert_equal 1 [r lpush mylist1 $largevalue(linkedlist)]
        # assert_encoding quicklist mylist1
        assert_equal 2 [r rpush mylist1 b]
        assert_equal 3 [r rpush mylist1 c]
        assert_equal 3 [r llen mylist1]
        assert_equal $largevalue(linkedlist) [r lindex mylist1 0]
        assert_equal b [r lindex mylist1 1]
        assert_equal c [r lindex mylist1 2]
        assert_equal {} [r lindex mylist1 3]
        assert_equal c [r rpop mylist1]
        assert_equal $largevalue(linkedlist) [r lpop mylist1]

        # first rpush then lpush
        assert_equal 1 [r rpush mylist2 $largevalue(linkedlist)]
        # assert_encoding quicklist mylist2
        assert_equal 2 [r lpush mylist2 b]
        assert_equal 3 [r lpush mylist2 c]
        assert_equal 3 [r llen mylist2]
        assert_equal c [r lindex mylist2 0]
        assert_equal b [r lindex mylist2 1]
        assert_equal $largevalue(linkedlist) [r lindex mylist2 2]
        assert_equal {} [r lindex mylist2 3]
        assert_equal $largevalue(linkedlist) [r rpop mylist2]
        assert_equal c [r lpop mylist2]
    }

    test {R/LPOP against empty list} {
        r lpop non-existing-list
    } {}

    test {Variadic RPUSH/LPUSH} {
        r del mylist
        assert_equal 4 [r lpush mylist a b c d]
        assert_equal 8 [r rpush mylist 0 1 2 3]
        assert_equal {d c b a 0 1 2 3} [r lrange mylist 0 -1]
    }

    test {DEL a list} {
        assert_equal 1 [r del mylist2]
        assert_equal 0 [r exists mylist2]
        assert_equal 0 [r llen mylist2]
    }

    proc create_list {key entries} {
        r del $key
        foreach entry $entries { r rpush $key $entry }
    }

    test {LPUSHX, RPUSHX - generic} {
        r del xlist
        assert_equal 0 [r lpushx xlist a]
        assert_equal 0 [r llen xlist]
        assert_equal 0 [r rpushx xlist a]
        assert_equal 0 [r llen xlist]
    }

    foreach {type large} [array get largevalue] {
        test "LPUSHX, RPUSHX - $type" {
            create_list xlist "$large c"
            assert_equal 3 [r rpushx xlist d]
            assert_equal 4 [r lpushx xlist a]
            assert_equal "a $large c d" [r lrange xlist 0 -1]
        }

        # test "LINSERT - $type" {
        #     create_list xlist "a $large c d"
        #     assert_equal 5 [r linsert xlist before c zz] "before c"
        #     assert_equal "a $large zz c d" [r lrange xlist 0 10] "lrangeA"
        #     assert_equal 6 [r linsert xlist after c yy] "after c"
        #     assert_equal "a $large zz c yy d" [r lrange xlist 0 10] "lrangeB"
        #     assert_equal 7 [r linsert xlist after d dd] "after d"
        #     assert_equal -1 [r linsert xlist after bad ddd] "after bad"
        #     assert_equal "a $large zz c yy d dd" [r lrange xlist 0 10] "lrangeC"
        #     assert_equal 8 [r linsert xlist before a aa] "before a"
        #     assert_equal -1 [r linsert xlist before bad aaa] "before bad"
        #     assert_equal "aa a $large zz c yy d dd" [r lrange xlist 0 10] "lrangeD"

        #     # check inserting integer encoded value
        #     assert_equal 9 [r linsert xlist before aa 42] "before aa"
        #     assert_equal 42 [r lrange xlist 0 0] "lrangeE"
        # }
    }

    # test {LINSERT raise error on bad syntax} {
    #     catch {[r linsert xlist aft3r aa 42]} e
    #     set e
    # } {*ERR*syntax*error*}

    foreach {type num} {quicklist 250 quicklist 500} {
        proc check_numbered_list_consistency {key} {
            set len [r llen $key]
            for {set i 0} {$i < $len} {incr i} {
                assert_equal $i [r lindex $key $i]
                assert_equal [expr $len-1-$i] [r lindex $key [expr (-$i)-1]]
            }
        }

        proc check_random_access_consistency {key} {
            set len [r llen $key]
            for {set i 0} {$i < $len} {incr i} {
                set rint [expr int(rand()*$len)]
                assert_equal $rint [r lindex $key $rint]
                assert_equal [expr $len-1-$rint] [r lindex $key [expr (-$rint)-1]]
            }
        }

        test "LINDEX consistency test - $type" {
            r del mylist
            for {set i 0} {$i < $num} {incr i} {
                r rpush mylist $i
            }
            # assert_encoding $type mylist
            check_numbered_list_consistency mylist
        }

        test "LINDEX random access - $type" {
            # assert_encoding $type mylist
            check_random_access_consistency mylist
        }

        test "Check if list is still ok after a DEBUG RELOAD - $type" {
            # r debug reload
            # assert_encoding $type mylist
            check_numbered_list_consistency mylist
            check_random_access_consistency mylist
        }
    }

    test {LLEN against non-list value error} {
        r del mylist
        r hset mylist foobar test
        assert_error ERR* {r llen mylist}
    }

    test {LLEN against non existing key} {
        assert_equal 0 [r llen not-a-key]
    }

    test {LINDEX against non-list value error} {
        assert_error ERR* {r lindex mylist 0}
    }

    test {LINDEX against non existing key} {
        assert_equal "" [r lindex not-a-key 10]
    }

    test {LPUSH against non-list value error} {
        assert_error ERR* {r lpush mylist 0}
    }

    test {RPUSH against non-list value error} {
        assert_error ERR* {r rpush mylist 0}
    }

    foreach {type large} [array get largevalue] {
        test "Basic LPOP/RPOP - $type" {
            create_list mylist "$large 1 2"
            assert_equal $large [r lpop mylist]
            assert_equal 2 [r rpop mylist]
            assert_equal 1 [r lpop mylist]
            assert_equal 0 [r llen mylist]

            # pop on empty list
            assert_equal {} [r lpop mylist]
            assert_equal {} [r rpop mylist]
        }
    }

    test {LPOP/RPOP against non list value} {
        r hset notalist foo test
        assert_error ERR* {r lpop notalist}
        assert_error ERR* {r rpop notalist}
    }

    foreach {type num} {quicklist 250 quicklist 500} {
        test "Mass RPOP/LPOP - $type" {
            r del mylist
            set sum1 0
            for {set i 0} {$i < $num} {incr i} {
                r lpush mylist $i
                incr sum1 $i
            }
            # assert_encoding $type mylist
            set sum2 0
            for {set i 0} {$i < [expr $num/2]} {incr i} {
                incr sum2 [r lpop mylist]
                incr sum2 [r rpop mylist]
            }
            assert_equal $sum1 $sum2
        }
    }

    foreach {type large} [array get largevalue] {
        test "LRANGE basics - $type" {
            create_list mylist "$large 1 2 3 4 5 6 7 8 9"
            assert_equal {1 2 3 4 5 6 7 8} [r lrange mylist 1 -2]
            assert_equal {7 8 9} [r lrange mylist -3 -1]
            assert_equal {4} [r lrange mylist 4 4]
        }

        test "LRANGE inverted indexes - $type" {
            create_list mylist "$large 1 2 3 4 5 6 7 8 9"
            assert_equal {} [r lrange mylist 6 2]
        }

        test "LRANGE out of range indexes including the full list - $type" {
            create_list mylist "$large 1 2 3"
            assert_equal "$large 1 2 3" [r lrange mylist -1000 1000]
        }

        test "LRANGE out of range negative end index - $type" {
            create_list mylist "$large 1 2 3"
            assert_equal $large [r lrange mylist 0 -4]
            assert_equal {} [r lrange mylist 0 -5]
        }
    }

    test {LRANGE against non existing key} {
        assert_equal {} [r lrange nosuchkey 0 1]
    }

    foreach {type large} [array get largevalue] {
        proc trim_list {type min max} {
            upvar 1 large large
            r del mylist
            create_list mylist "1 2 3 4 $large"
            r ltrim mylist $min $max
            r lrange mylist 0 -1
        }

        test "LTRIM basics - $type" {
            assert_equal "1" [trim_list $type 0 0]
            assert_equal "1 2" [trim_list $type 0 1]
            assert_equal "1 2 3" [trim_list $type 0 2]
            assert_equal "2 3" [trim_list $type 1 2]
            assert_equal "2 3 4 $large" [trim_list $type 1 -1]
            assert_equal "2 3 4" [trim_list $type 1 -2]
            assert_equal "4 $large" [trim_list $type -2 -1]
            assert_equal "$large" [trim_list $type -1 -1]
            assert_equal "1 2 3 4 $large" [trim_list $type -5 -1]
            assert_equal "1 2 3 4 $large" [trim_list $type -10 10]
            assert_equal "1 2 3 4 $large" [trim_list $type 0 5]
            assert_equal "1 2 3 4 $large" [trim_list $type 0 10]
        }

        test "LTRIM out of range negative end index - $type" {
            assert_equal {1} [trim_list $type 0 -5]
            assert_equal {} [trim_list $type 0 -6]
        }

    }

    foreach {type large} [array get largevalue] {
        test "LSET - $type" {
            create_list mylist "99 98 $large 96 95"
            r lset mylist 1 foo
            r lset mylist -1 bar
            assert_equal "99 foo $large 96 bar" [r lrange mylist 0 -1]
        }

        test "LSET out of range index - $type" {
            assert_error ERR* {r lset mylist 10 foo}
        }
    }

    test {LSET against non existing key} {
        assert_error ERR* {r lset nosuchkey 10 foo}
    }

    test {LSET against non list value} {
        r hset nolist foobar test
        assert_error ERR* {r lset nolist 0 foo}
    }

    foreach {type e} [array get largevalue] {
        test "LREM remove all the occurrences - $type" {
            create_list mylist "$e foo bar foobar foobared zap bar test foo"
            assert_equal 2 [r lrem mylist 0 bar]
            assert_equal "$e foo foobar foobared zap test foo" [r lrange mylist 0 -1]
        }

        test "LREM remove the first occurrence - $type" {
            assert_equal 1 [r lrem mylist 1 foo]
            assert_equal "$e foobar foobared zap test foo" [r lrange mylist 0 -1]
        }

        test "LREM remove non existing element - $type" {
            assert_equal 0 [r lrem mylist 1 nosuchelement]
            assert_equal "$e foobar foobared zap test foo" [r lrange mylist 0 -1]
        }

        test "LREM starting from tail with negative count - $type" {
            create_list mylist "$e foo bar foobar foobared zap bar test foo foo"
            assert_equal 1 [r lrem mylist -1 bar]
            assert_equal "$e foo bar foobar foobared zap test foo foo" [r lrange mylist 0 -1]
        }

        test "LREM starting from tail with negative count (2) - $type" {
            assert_equal 2 [r lrem mylist -2 foo]
            assert_equal "$e foo bar foobar foobared zap test" [r lrange mylist 0 -1]
        }

        test "LREM deleting objects that may be int encoded - $type" {
            create_list myotherlist "$e 1 2 3"
            assert_equal 1 [r lrem myotherlist 1 2]
            assert_equal 3 [r llen myotherlist]
        }
    }

    test "List lpush and lpop" {
        for {set i 0} {$i < 2} {incr i} {
            r del mylist3
            r lpush mylist3 1 2 3
            r lpush mylist3 4 5 6
            r lpush mylist3 7 8 9 10
            assert_equal "type list deleted false version $i maxlen 0 length 10 pruning min minindex -9 maxindex 0" [r meta mylist3]
            assert_equal "10 9 8 7 6 5 4 3 2 1" [r lrange mylist3 0 -1]
            assert_equal "10 9 8" [r lrange mylist3 0 2]
            assert_equal "3 2 1" [r lrange mylist3 -3 -1]
            assert_equal "5 4 3 2 1" [r lrange mylist3 5 -1]
            assert_equal "5 4 3 2 1" [r lrange mylist3 5 9]
        }
        r lpop mylist3
        r lpop mylist3
        r lpop mylist3
        assert_equal "type list deleted false version 1 maxlen 0 length 7 pruning min minindex -6 maxindex 0" [r meta mylist3]
    }

    test "List rpush and rpop" {
        for {set i 0} {$i < 2} {incr i} {
            r del mylist4
            r rpush mylist4 1 2 3
            r rpush mylist4 4 5 6
            r rpush mylist4 7 8 9 10
            assert_equal "type list deleted false version $i maxlen 0 length 10 pruning min minindex 0 maxindex 9" [r meta mylist4]
            assert_equal "1 2 3 4 5 6 7 8 9 10" [r lrange mylist4 0 -1]
            assert_equal "1 2 3" [r lrange mylist4 0 2]
            assert_equal "8 9 10" [r lrange mylist4 -3 -1]
            assert_equal "6 7 8 9 10" [r lrange mylist4 5 -1]
            assert_equal "6 7 8 9 10" [r lrange mylist4 5 9]
        }
        r rpop mylist4
        r rpop mylist4
        r rpop mylist4
        assert_equal "type list deleted false version 1 maxlen 0 length 7 pruning min minindex 0 maxindex 6" [r meta mylist4]
    }

    test "List *push and *pop" {
        r rpush mylist5 1 2 3
        r rpush mylist5 4 5 6
        r rpush mylist5 7 8 9 10
        r lpush mylist5 a b c
        r lpush mylist5 d e f
        r lpush mylist5 g h i j
        assert_equal "type list deleted false version 0 maxlen 0 length 20 pruning min minindex -10 maxindex 9" [r meta mylist5]
        assert_equal "j i h g f e d c b a 1 2 3 4 5 6 7 8 9 10" [r lrange mylist5 0 -1]
        r rpop mylist5
        r rpop mylist5
        r rpop mylist5
        r lpop mylist5
        r lpop mylist5
        r lpop mylist5
        assert_equal "type list deleted false version 0 maxlen 0 length 14 pruning min minindex -7 maxindex 6" [r meta mylist5]
        assert_equal "g f e d c b a 1 2 3 4 5 6 7" [r lrange mylist5 0 -1]
    }

    test "List lset" {
        assert_error ERR* {r lset mylist6 0 a}
        create_list mylist6 "1 2 3 4 5 6 7 8 9"
        assert_equal "OK" [r lset mylist6 0 a]
        assert_equal "OK" [r lset mylist6 7 c]
        assert_equal "OK" [r lset mylist6 -1 b]
        assert_equal "OK" [r lset mylist6 -8 d]
        assert_equal "a d 3 4 5 6 7 c b" [r lrange mylist6 0 -1]
        assert_error ERR* {r lset mylist6 100 c}
        assert_error ERR* {r lset mylist6 -100 d}
        assert_equal "type list deleted false version 0 maxlen 0 length 9 pruning min minindex 0 maxindex 8" [r meta mylist6]
    }

    # test "Regression for bug 593 - chaining BRPOPLPUSH with other blocking cmds" {
    #     set rd1 [redis_deferring_client]
    #     set rd2 [redis_deferring_client]

    #     $rd1 brpoplpush a b 0
    #     $rd1 brpoplpush a b 0
    #     $rd2 brpoplpush b c 0
    #     after 1000
    #     r lpush a data
    #     $rd1 close
    #     $rd2 close
    #     r ping
    # } {PONG}
}
