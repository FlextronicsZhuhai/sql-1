# encoding: utf-8

require 'spec_helper'

# FIXME: split this spec into smaller files
describe SQL::Generator::Emitter, '.visit' do
  include_context 'emitter'

  context 'with literal singletons' do
    assert_generates s(:true),  'TRUE'
    assert_generates s(:false), 'FALSE'
    assert_generates s(:null),  'NULL'
  end

  context 'with strings' do
    assert_generates s(:string, %q[echo 'Hello']), %q['echo ''Hello''']
  end

  context 'with integers' do
    assert_generates s(:integer, 1), '1'
  end

  context 'with floats' do
    assert_generates s(:float, 1.0), '1.0'
  end

  context 'with decimals' do
    assert_generates s(:decimal, BigDecimal('1.0')), '1.0'
  end

  context 'with dates' do
    assert_generates s(:date, Date.new(2013, 1, 1)), %q['2013-01-01']
  end

  context 'with datetimes' do
    nsec_in_seconds = Rational(1, 10**9)
    offset          = Rational(-8, 24)

    # A DateTime not in the UTC timezone
    datetime = DateTime.new(2013, 12, 31, 15, 59, 59 + nsec_in_seconds, offset)

    assert_generates(
      s(:datetime, datetime),
      %q['2013-12-31T23:59:59.000000001+00:00']  # converts to UTC
    )
  end

  context 'with times' do
    # A Time not in the UTC timezone
    time = begin
      original, ENV['TZ'] = ENV['TZ'], 'America/Vancouver'
      Time.local(2010, 12, 31, 15, 59, 59, 1).freeze
    ensure
      ENV['TZ'] = original
    end

    assert_generates(
      s(:time, time),
      %q['2010-12-31T23:59:59.000001000Z']  # converts to UTC
    )
  end

  context 'identifiers' do
    assert_generates s(:id, 'echo "oh hai"'), '"echo ""oh hai"""'
  end

  context 'unary prefix operations' do
    context 'with plus' do
      assert_generates s(:uplus, s(:integer, 1)), '+1'
    end

    context 'with minus' do
      assert_generates s(:uminus, s(:integer, 1)), '-1'
    end

    context 'with negation' do
      assert_generates s(:not, s(:true)), 'NOT TRUE'
    end
  end

  context 'unary function operations' do
    {
      count:  'COUNT',
      sum:    'SUM',
      min:    'MIN',
      max:    'MAX',
      avg:    'AVG',
      var:    'VAR_POP',
      stddev: 'STDDEV_POP',
      sqrt:   'SQRT',
      abs:    'ABS',
      length: 'LENGTH',
    }.each do |type, operator|
      context type.inspect do
        assert_generates(
          s(type, s(:id, 'foo')),
          %Q[#{operator} ("foo")]
        )
      end
    end
  end

  context 'binary infix operations' do
    {
      or:     'OR',
      and:    'AND',
      concat: '||',
      mul:    '*',
      add:    '+',
      sub:    '-',
      div:    '/',
      mod:    '%',
      pow:    '^',
      eq:     '=',
      ne:     '<>',
      gt:     '>',
      gte:    '>=',
      lt:     '<',
      lte:    '<=',
    }.each do |type, operator|
      context type.inspect do
        assert_generates(
          s(type, s(:id, 'foo'), s(:id, 'bar')),
          %Q["foo" #{operator} "bar"]
        )
      end
    end

    context ':is' do
      assert_generates(
        s(:is, s(:id, 'foo'), s(:null)),
        '"foo" IS NULL'
      )

      assert_generates(
        s(:is, s(:id, 'foo'), s(:not, s(:null))),
        '"foo" IS NOT NULL'
      )
    end

    context ':in' do
      assert_generates(
        s(:in, s(:id, 'foo'), s(:tuple, s(:integer, 1), s(:integer, 2))),
        '"foo" IN (1, 2)'
      )
    end

    context ':between' do
      assert_generates(
        s(:between, s(:id, 'foo'), s(:and, s(:integer, 1), s(:integer, 2))),
        '"foo" BETWEEN 1 AND 2'
      )
    end
  end

  context 'tuples' do
    assert_generates(
      s(:tuple, s(:integer, 1), s(:string, 'foo')),
      "(1, 'foo')"
    )
  end

  context 'insert' do
    assert_generates(
      s(:insert,
        s(:id, 'users'),
        s(:tuple, s(:integer, 1), s(:string, 'foo'))
      ),
      %q[INSERT INTO "users" VALUES (1, 'foo')]
    )
  end

  context 'delete' do
    context 'without where clause' do
      assert_generates s(:delete, s(:id, 'users')), %q[DELETE FROM "users"]
    end

    context 'with where clause' do
      assert_generates(
        s(:delete,
          s(:id, 'users'),
          s(:where,
            s(:eq, s(:id, 'name'), s(:string, 'foo'))
          )
        ),
        %q[DELETE FROM "users" WHERE "name" = 'foo']
      )
    end
  end

  context 'update' do
    context 'without where clause' do
      assert_generates(
        s(:update,
          s(:id, 'users'),
          s(:set,
            s(:eq, s(:id, 'name'), s(:string, 'foo')),
            s(:eq, s(:id, 'age'), s(:integer, 1))
          )
        ),
        %q[UPDATE "users" SET "name" = 'foo', "age" = 1]
      )
    end

    context 'with where clause' do
      assert_generates(
        s(:update,
          s(:id, 'users'),
          s(:set,
            s(:eq, s(:id, 'name'), s(:string, 'foo')),
            s(:eq, s(:id, 'age'), s(:integer, 1))
          ),
          s(:where,
            s(:eq, s(:id, 'age'), s(:integer, 2))
          )
        ),
        <<-SQL.gsub(/\s+/, ' ').strip
          UPDATE "users"
          SET "name" = 'foo', "age" = 1
          WHERE "age" = 2
        SQL
      )
    end
  end

  context 'select' do
    context 'without where clause' do
      assert_generates(
        s(:select,
          s(:fields, s(:id, 'name'), s(:id, 'age')), s(:id, 'users')
        ),
        %q[SELECT "name", "age" FROM "users"]
      )
    end

    context 'with where clause' do
      assert_generates(
        s(:select,
          s(:fields,
            s(:id, 'name'), s(:id, 'age')
          ),
          s(:id, 'users'),
          s(:where,
            s(:eq, s(:id, 'id'), s(:integer, 1))
          )
        ),
        %q[SELECT "name", "age" FROM "users" WHERE "id" = 1]
      )
    end

    context 'with group by' do
      assert_generates(
        s(:select,
          s(:fields, s(:id, 'name'), s(:id, 'age')),
          s(:id, 'users'),
          s(:group_by, s(:id, 'name'), s(:id, 'age'))
        ),
        <<-SQL.gsub(/\s+/, ' ').strip
          SELECT "name", "age"
          FROM "users"
          GROUP BY "name", "age"
        SQL
      )
    end

    context 'with order by' do
      assert_generates(
        s(:select,
          s(:fields, s(:id, 'name'), s(:id, 'age')),
          s(:id, 'users'),
          s(:order_by, s(:asc, s(:id, 'name')), s(:desc, s(:id, 'age')))
        ),
        <<-SQL.gsub(/\s+/, ' ').strip
          SELECT "name", "age"
          FROM "users"
          ORDER BY "name" ASC, "age" DESC
        SQL
      )
    end

    context 'with having' do
      assert_generates(
        s(:select,
          s(:fields, s(:id, 'name'), s(:id, 'age')),
          s(:id, 'users'),
          s(:group_by, s(:id, 'name'), s(:id, 'age')),
          s(:having, s(:eq, s(:id, 'id'), s(:integer, 1)))
        ),
        <<-SQL.gsub(/\s+/, ' ').strip
          SELECT "name", "age"
          FROM "users"
          GROUP BY "name", "age"
          HAVING "id" = 1
        SQL
      )
    end
  end

  context 'set operations' do
    {
      difference:   'EXCEPT',
      intersection: 'INTERSECT',
      union:        'UNION',
    }.each do |type, operator|
      context type.inspect do
        assert_generates(
          s(type,
            s(:select, s(:fields, s(:id, 'name')), s(:id, 'users')),
            s(:select, s(:fields, s(:id, 'name')), s(:id, 'customers')),
            s(:select, s(:fields, s(:id, 'name')), s(:id, 'employees')),
          ),
          <<-SQL.gsub(/\s+/, ' ').strip
            (SELECT "name" FROM "users")
            #{operator}
            (SELECT "name" FROM "customers")
            #{operator}
            (SELECT "name" FROM "employees")
          SQL
        )
      end
    end
  end

  context 'join operations' do
    {
      join:       'JOIN',
      left_join:  'LEFT JOIN',
      right_join: 'RIGHT JOIN',
      full_join:  'FULL JOIN',
    }.each do |type, operator|
      context type.inspect do
        assert_generates(
          s(type,
            s(:id, 'foo'),
            s(:id, 'bar'),
            s(:on, s(:eq, s(:id, 'foo', 'name'), s(:id, 'bar', 'name')))
          ),
          %Q["foo" #{operator} "bar" ON "foo"."name" = "bar"."name"]
        )

        assert_generates(
          s(type,
            s(:id, 'foo'),
            s(:id, 'bar'),
            s(:using, s(:tuple, s(:id, 'name')))
          ),
          %Q["foo" #{operator} "bar" USING ("name")]
        )
      end
    end

    {
      natural_join: 'NATURAL JOIN',
      cross_join:   'CROSS JOIN',
    }.each do |type, operator|
      context type.inspect do
        assert_generates(
          s(type, s(:id, 'foo'), s(:id, 'bar')),
          %Q["foo" #{operator} "bar"]
        )
      end
    end
  end

  context 'when emitter is missing' do
    it 'raises argument error' do
      expect { described_class.visit(s(:not_supported, []), stream) }
        .to raise_error(
          SQL::UnknownTypeError,
          'No emitter for node: :not_supported'
        )
    end
  end
end
