-- スケジュール繰り返し機能

with
  -- パラメータ
  parameter as (
    select
      '2022-02-01'::timestamp as start_date, -- 開始日
      '2022-04-30'::timestamp as end_date, -- 終了日
      -- TODO この値を変えることで週の始まりの曜日を切り替えられるようにする
      0 as start_day_of_week -- 週の始まりの曜日 ※日曜～土曜をそれぞれ0～6とする
  ),

  -- スケジュール
  schedule as (
    select
      *
    from
      (
        values
          (1001, 'テストスケジュール1: 3日ごと'),
          (1002, 'テストスケジュール2: 3週ごと の 月/水曜日'),
          (1003, 'テストスケジュール3: 3ヶ月ごと の 4週目 の月/水曜日'),
          (1004, 'テストスケジュール4: 3ヶ月ごと の 最終週 の月/水曜日'),
          (1005, 'テストスケジュール5: 3ヶ月ごと の 4回目 の月/水曜日'),
          (1006, 'テストスケジュール6: 3ヶ月ごと の 最終 の月/水曜日'),
          (1007, 'テストスケジュール7: 3ヶ月ごと の 10,20日'),
          (1008, 'テストスケジュール8: 3ヶ月ごと の 10,29,31日 ※該当月に指定日にちが存在しない場合は月末日'),
          (1009, 'テストスケジュール9: 3ヶ月ごと の 月末日'),
          (1010, 'テストスケジュール10')
      ) as schedule (
        id,
        title
      )
  ),

  -- スケジュール繰り返し設定
  schedule_repeat_setting as (
    select
      *
    from
      (
        values
          -- n日ごと
          (2001, 1001, 'every-n-days', '{ "days": 3 }'::json, '2022-01-01'::timestamp, '2022-12-31'::timestamp),

          -- n週ごと の 指定曜日
          (2002, 1002, 'x-days-of-week-every-n-weeks', '{ "weeks": 3, "days-of-week": [1, 3] }'::json, '2022-01-01'::timestamp, '2022-12-31'::timestamp),

          -- nヶ月ごと の m週目 の 指定曜日
          (2003, 1003, 'x-days-of-mth-week-every-n-months', '{ "months": 3, "week-number": 4, "days-of-week": [1, 3] }'::json, '2022-01-01'::timestamp, '2022-12-31'::timestamp),

          -- nヶ月ごと の 最終週 の 指定曜日
          (2004, 1004, 'x-days-of-last-week-every-n-months', '{ "months": 3, "days-of-week": [1, 3] }'::json, '2022-01-01'::timestamp, '2022-12-31'::timestamp),

          -- nヶ月ごと の m回目 の 指定曜日
          (2005, 1005, 'mth-x-days-of-week-every-n-months', '{ "months": 3, "times-days-of-week": 4, "days-of-week": [1, 3] }'::json, '2022-01-01'::timestamp, '2022-12-31'::timestamp),

          -- nヶ月ごと の 最終 の 指定曜日
          (2006, 1006, 'last-x-days-of-week-every-n-months', '{ "months": 3, "days-of-week": [1, 3] }'::json, '2022-01-01'::timestamp, '2022-12-31'::timestamp),

          -- nヶ月ごと の 指定日にち
          (2007, 1007, 'xth-of-every-n-months', '{ "months": 3, "days-of-month": [10, 20] }'::json, '2022-01-01'::timestamp, '2022-12-31'::timestamp),

          -- nヶ月ごと の 指定日にち ※該当月に指定日にちが存在しない場合は月末日
          (2008, 1008, 'xth-of-every-n-months-or-end-of-every-n-months', '{ "months": 3, "days-of-month": [10, 29, 31] }'::json, '2022-01-01'::timestamp, '2022-12-31'::timestamp),

          -- nヶ月ごと の 月末
          (2009, 1009, 'end-of-every-n-months', '{ "months": 3 }'::json, '2022-01-01'::timestamp, null),

          -- TODO 境界値テストとなるようにテストデータを修正する
          -- 検索対象期間外
          (2010, 1010, 'every-n-days', '{ "days": 3 }'::json, '2023-01-01'::timestamp, '2023-12-31'::timestamp)
      ) as schedule_repeat_setting (
        id,
        schedule_id,
        repeat_type,
        repeat_parameters,
        repeat_start_date,
        repeat_end_date
      )
  )

select
  repeat_schedule.title,
  repeat_schedule.schedule_group_id,
  unnest(
    (
      select
        array_agg(repeated_dates.repeated_date)
      from
        (
          select
            repeated_date,
            -- 繰り返し開始日から対象日までの経過日数
            date_part('day', repeated_date - repeat_schedule.repeat_start_date)::integer as days,
            -- 繰り返し開始日から対象日までの経過週数
            date_part('day', repeated_date - repeat_schedule.repeat_start_date)::integer / 7 as weeks,
            -- 対象日の日にち
            date_part('day', repeated_dates.repeated_date)::integer as day,
            -- 対象日の曜日
            date_part('dow', repeated_date)::integer as dayOfWeek,
            -- 繰り返し開始日の月から対象日の月までの経過月数
            date_part('month', age(repeated_date, repeat_schedule.repeat_start_date))::integer as months,
            -- 対象日の月の月末日
            date_trunc('month', repeated_date) + '1 month' + '-1 day' as lastDateOfMonth,
            -- 対象日の月の月末の日にち
            date_part('day', date_trunc('month', repeated_date) + '1 month' + '-1 day')::integer as lastDayOfMonth,
            -- 対象日の月の月初日の週の始まりの日
            (date_trunc('month', repeated_date) - cast(date_part('dow', date_trunc('month', repeated_date)) || 'day' as interval)) as firstDateOfWeekOnFirstDayOfMonth
          from
            generate_series (
              greatest(repeat_schedule.repeat_start_date, (select start_date from parameter)),
              least(repeat_schedule.repeat_end_date, (select end_date from parameter)),
              '1 days'
            ) as repeated_dates ( repeated_date )
        ) repeated_dates
      where
        case repeat_schedule.repeat_type

        -- n日ごと
        when 'every-n-days' then (
            -- n日ごと
            repeated_dates.days % repeat_schedule.days = 0
        )

        -- n週ごと の 指定曜日
        when 'x-days-of-week-every-n-weeks' then (
            -- n週ごと
            repeated_dates.weeks % repeat_schedule.weeks = 0

            -- 指定曜日
            and array[repeated_dates.dayOfWeek] <@ repeat_schedule.daysOfWeek
        )

        -- nヶ月ごと の m週目 の 指定曜日
        when 'x-days-of-mth-week-every-n-months' then (
            -- nヶ月ごと
            repeated_dates.months % repeat_schedule.months = 0

            -- m週目
            -- NOTE: "対象日の月初日"がある週の始まりの日 から 対象日 までの経過日数を7で割った際の商で、該当月において何週目かを判定
            and date_part('day', repeated_dates.repeated_date - repeated_dates.firstDateOfWeekOnFirstDayOfMonth)::integer / 7 + 1
              = repeat_schedule.weekNumber

            -- 指定曜日
            and array[repeated_dates.dayOfWeek] <@ repeat_schedule.daysOfWeek
        )

        -- nヶ月ごと の 最終週 の 指定曜日
        when 'x-days-of-last-week-every-n-months' then (
            -- nヶ月ごと
            repeated_dates.months % repeat_schedule.months = 0

            -- 最終週
            -- NOTE: "対象日の月初日"がある週の始まりの日 から 対象日 までの経過日数を7で割った際の商で、該当月において何週目かを判定
            and date_part('day', repeated_dates.repeated_date - repeated_dates.firstDateOfWeekOnFirstDayOfMonth)::integer / 7 + 1
              = date_part('day', repeated_dates.lastDateOfMonth - repeated_dates.firstDateOfWeekOnFirstDayOfMonth)::integer / 7 + 1

            -- 指定曜日
            and array[repeated_dates.dayOfWeek] <@ repeat_schedule.daysOfWeek
        )

        -- nヶ月ごと の m回目 の 指定曜日
        when 'mth-x-days-of-week-every-n-months' then (
            -- nヶ月ごと
            repeated_dates.months % repeat_schedule.months = 0

            -- 第m回目
            and date_part('day', repeated_dates.repeated_date - date_trunc('month', repeated_dates.repeated_date))::integer / 7 + 1
              = repeat_schedule.timesDaysOfWeek

            -- 指定曜日
            and array[repeated_dates.dayOfWeek] <@ repeat_schedule.daysOfWeek
        )

        -- nヶ月ごと の 最終 の 指定曜日
        when 'last-x-days-of-week-every-n-months' then (
          -- nヶ月ごと
          repeated_dates.months % repeat_schedule.months = 0

          -- 最終
          and date_part('day', repeated_dates.lastDateOfMonth - repeated_dates.repeated_date) < 7

          -- 指定曜日
          and array[repeated_dates.dayOfWeek] <@ repeat_schedule.daysOfWeek
        )

        -- nヶ月ごと の 指定日にち
        when 'xth-of-every-n-months' then (
          -- nヶ月ごと
          repeated_dates.months % repeat_schedule.months = 0

          -- 指定日にち
          and array[day] <@ repeat_schedule.daysOfMonth
        )

        -- nヶ月ごと の 指定日にち ※該当月に指定日にちが存在しない場合は月末日
        when 'xth-of-every-n-months-or-end-of-every-n-months' then (
          -- nヶ月ごと
          repeated_dates.months % repeat_schedule.months = 0

          and (
            -- 指定日にち
            array[repeated_dates.day] <@ repeat_schedule.daysOfMonth

            -- (該当月に指定日にちが存在しない場合は)月末日
            or (
              -- 月末の日にちより大きい日にちが指定されている
              repeated_dates.lastDayOfMonth < any(repeat_schedule.daysOfMonth)
              -- 対象日が月末日
              and repeated_dates.repeated_date = repeated_dates.lastDateOfMonth
            )
          )
        )

        -- nヶ月ごと の 月末
        when 'end-of-every-n-months' then (
          -- nヶ月ごと
          repeated_dates.months % repeat_schedule.months = 0

          -- 月末
          and repeated_dates.repeated_date = repeated_dates.lastDateOfMonth
        )

        -- その他
        else 1 = 0

        end
    )
  ) as repeated_day
from
  (
    select
      s.*,
      r.*,
      r.id as schedule_group_id,
      (r.repeat_parameters->>'days')::integer as days,
      (r.repeat_parameters->>'weeks')::integer as weeks,
      (r.repeat_parameters->>'months')::integer as months,
      (r.repeat_parameters->>'week-number')::integer as weekNumber,
      (r.repeat_parameters->>'times-days-of-week')::integer as timesDaysOfWeek,
      (select array_agg(dayOfWeek)::integer[] from (select json_array_elements_text(r.repeat_parameters->'days-of-week')) daysOfWeek (dayOfWeek)) as daysOfWeek,
      (select array_agg(dayOfMonth)::integer[] from (select json_array_elements_text(r.repeat_parameters->'days-of-month')) daysOfMonth (dayOfMonth)) as daysOfMonth
    from
      schedule s
      inner join schedule_repeat_setting r on
        r.schedule_id = s.id
    where
      -- 繰り返し期間が検索対象期間と重複していること
      r.repeat_start_date <= (select end_date from parameter)
      and (
        r.repeat_end_date is null
        or r.repeat_end_date >= (select start_date from parameter)
      )
  ) repeat_schedule
;
