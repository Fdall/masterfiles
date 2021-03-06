BEGIN {
    # split lines on SQL keywords
    # lines are like "INSERT INTO table_name (col1, col2) VALUES (val1, val2);"
    FS = "(INSERT INTO|VALUES)"

    # Output Record Separator -- "\n" by default, we need greater control
    ORS = ""

    # helper variables
    table_name = ""
    counter = 0

    # maximum rows per one INSERT INTO statement (we need to limit this because
    # otherwise PostgreSQL can easily run out of memory when buffering things)
    max_per_statement = 10000
}

/^INSERT INTO/ {
    # "INSERT INTO table_name (col1, col2) VALUES (val1, val2);"
    # $1 == ""
    # $2 == "table_name (col1, col2)"
    # $3 == "(val1, val2);"

    # split the "table_name (col1, col2)" field on spaces
    split($2, fields, " ")

    # trim ";" from the "VALUES (val1, val2);" part
    values = substr($3, 0, (length($3) - 1));

    if (table_name == "") {
        # starting with a new table, store its name and write out the beginning
        # of the INSERT INTO statement
        table_name = fields[1]
        print "INSERT INTO"$2"VALUES \n"values
        counter = 1
    }
    else {
        if (table_name == fields[1]) {
            # another line inserting into the same table
            if (counter == max_per_statement) {
                # reached the limit of maximum rows per one INSERT INTO statement
                # terminate it and start a new one for the same table
                print ";\n"
                print "INSERT INTO"$2"VALUES \n"values
                counter = 1
            }
            else {
                # more rows for the same table
                # write ",\n" after the previous row first, write the row and
                # increment the counter
                print ",\n"values
                counter++
            }
        }
        else {
            # a different table, terminate the INSERT INTO statement for the
            # previous table, start a new one for the new table and reset the
            # counter of rows per one statement
            print ";\n"
            print "\n"
            print "INSERT INTO"$2"VALUES \n"values
            counter = 1
        }
    }
}

!/^INSERT INTO/ {
    # all the other lines (empty, different SQL statements, comments,...)

    if (table_name != "") {
        # the previous line(s) where INSERT INTO statements into some table,
        # let's terminate the statement, remember we are not in the process
        # of adding rows to any INSERT INTO statement and reset the counter
        print ";\n"
        table_name = ""
        counter = 0
    }

    # in any case just print/preserve the line
    print $0"\n"
}
