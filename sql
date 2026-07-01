-- ============================================================
-- Bank Customer Churn Analysis — SQL
-- Dataset: Churn_Modelling.csv
-- Table: customers
-- ============================================================
-- Структура таблицы:
--   customer_id     INT       — уникальный ID клиента
--   credit_score    INT       — кредитный скор (350–850)
--   geography       TEXT      — страна (France / Germany / Spain)
--   gender          TEXT      — пол (Male / Female)
--   age             INT       — возраст
--   tenure          INT       — лет в банке (0–10)
--   balance         FLOAT     — баланс счёта
--   num_products    INT       — количество продуктов банка
--   has_credit_card INT       — есть кредитная карта (0/1)
--   is_active       INT       — активный клиент (0/1)
--   salary          FLOAT     — предполагаемая зарплата
--   exited          INT       — ушёл (1) / остался (0)
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- В1. Общий уровень оттока: сколько клиентов ушло и какова доля?
-- ─────────────────────────────────────────────────────────────
SELECT
    exited,
    CASE exited WHEN 1 THEN 'Ушёл' ELSE 'Остался' END AS status,
    COUNT(*)                                            AS total_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM customers
GROUP BY exited
ORDER BY exited DESC;


-- ─────────────────────────────────────────────────────────────
-- В2. Уровень оттока по странам: где клиенты уходят чаще всего?
-- ─────────────────────────────────────────────────────────────
SELECT
    geography,
    COUNT(*)                                                         AS total_customers,
    SUM(exited)                                                      AS churned,
    COUNT(*) - SUM(exited)                                          AS retained,
    ROUND(SUM(exited) * 100.0 / COUNT(*), 1)                        AS churn_rate_pct
FROM customers
GROUP BY geography
ORDER BY churn_rate_pct DESC;


-- ─────────────────────────────────────────────────────────────
-- В3. Уровень оттока по полу и стране одновременно.
-- ─────────────────────────────────────────────────────────────
SELECT
    geography,
    gender,
    COUNT(*)                                          AS total_customers,
    SUM(exited)                                       AS churned,
    ROUND(SUM(exited) * 100.0 / COUNT(*), 1)          AS churn_rate_pct
FROM customers
GROUP BY geography, gender
ORDER BY churn_rate_pct DESC;


-- ─────────────────────────────────────────────────────────────
-- В4. Влияет ли количество продуктов банка на отток?
-- ─────────────────────────────────────────────────────────────
SELECT
    num_products,
    COUNT(*)                                          AS total_customers,
    SUM(exited)                                       AS churned,
    ROUND(SUM(exited) * 100.0 / COUNT(*), 1)          AS churn_rate_pct,
    ROUND(AVG(balance), 2)                            AS avg_balance
FROM customers
GROUP BY num_products
ORDER BY num_products;


-- ─────────────────────────────────────────────────────────────
-- В5. Активные vs неактивные клиенты: кто уходит чаще?
-- ─────────────────────────────────────────────────────────────
SELECT
    CASE is_active
        WHEN 1 THEN 'Активный'
        ELSE 'Неактивный'
    END                                               AS activity_status,
    COUNT(*)                                          AS total_customers,
    SUM(exited)                                       AS churned,
    ROUND(SUM(exited) * 100.0 / COUNT(*), 1)          AS churn_rate_pct,
    ROUND(AVG(credit_score), 1)                       AS avg_credit_score
FROM customers
GROUP BY is_active
ORDER BY churn_rate_pct DESC;


-- ─────────────────────────────────────────────────────────────
-- В6. Отток по возрастным группам: влияет ли возраст на уход?
-- ─────────────────────────────────────────────────────────────
SELECT
    CASE
        WHEN age < 30              THEN '18–29 (молодые)'
        WHEN age BETWEEN 30 AND 44 THEN '30–44 (средний возраст)'
        WHEN age BETWEEN 45 AND 59 THEN '45–59 (зрелые)'
        ELSE '60+ (пожилые)'
    END                                               AS age_group,
    COUNT(*)                                          AS total_customers,
    SUM(exited)                                       AS churned,
    ROUND(SUM(exited) * 100.0 / COUNT(*), 1)          AS churn_rate_pct,
    ROUND(AVG(balance), 2)                            AS avg_balance
FROM customers
GROUP BY age_group
ORDER BY churn_rate_pct DESC;


-- ─────────────────────────────────────────────────────────────
-- В7. Разбивка по балансу: уходят ли клиенты с высоким балансом?
-- ─────────────────────────────────────────────────────────────
SELECT
    CASE
        WHEN balance = 0               THEN 'Нулевой баланс'
        WHEN balance BETWEEN 0.01 AND 50000  THEN 'Низкий (0–50k)'
        WHEN balance BETWEEN 50001 AND 100000 THEN 'Средний (50k–100k)'
        WHEN balance BETWEEN 100001 AND 150000 THEN 'Высокий (100k–150k)'
        ELSE 'Очень высокий (150k+)'
    END                                               AS balance_group,
    COUNT(*)                                          AS total_customers,
    SUM(exited)                                       AS churned,
    ROUND(SUM(exited) * 100.0 / COUNT(*), 1)          AS churn_rate_pct,
    ROUND(AVG(age), 1)                                AS avg_age
FROM customers
GROUP BY balance_group
ORDER BY churn_rate_pct DESC;


-- ─────────────────────────────────────────────────────────────
-- В8. Топ-5 профилей ушедших клиентов с самым высоким балансом.
-- ─────────────────────────────────────────────────────────────
SELECT
    customer_id,
    geography,
    gender,
    age,
    tenure,
    ROUND(balance, 2)      AS balance,
    num_products,
    CASE is_active WHEN 1 THEN 'Активный' ELSE 'Неактивный' END AS activity,
    credit_score
FROM customers
WHERE exited = 1
ORDER BY balance DESC
LIMIT 5;


-- ─────────────────────────────────────────────────────────────
-- В9. CTE: среднее по группам и выявление клиентов с балансом
--     выше среднего по своей стране, которые при этом ушли.
-- ─────────────────────────────────────────────────────────────
WITH country_avg AS (
    SELECT
        geography,
        ROUND(AVG(balance), 2) AS avg_balance_in_country
    FROM customers
    GROUP BY geography
)
SELECT
    c.customer_id,
    c.geography,
    c.gender,
    c.age,
    ROUND(c.balance, 2)            AS balance,
    ca.avg_balance_in_country,
    ROUND(c.balance - ca.avg_balance_in_country, 2) AS diff_from_avg,
    c.num_products,
    c.credit_score
FROM customers c
JOIN country_avg ca ON c.geography = ca.geography
WHERE c.exited = 1
  AND c.balance > ca.avg_balance_in_country
ORDER BY diff_from_avg DESC
LIMIT 10;


-- ─────────────────────────────────────────────────────────────
-- В10. Оконные функции: ранжирование клиентов по балансу
--      внутри каждой страны + доля ушедших в топ-квартиле.
-- ─────────────────────────────────────────────────────────────
WITH ranked AS (
    SELECT
        customer_id,
        geography,
        age,
        ROUND(balance, 2)                                             AS balance,
        exited,
        NTILE(4) OVER (PARTITION BY geography ORDER BY balance DESC)  AS balance_quartile,
        ROUND(AVG(balance) OVER (PARTITION BY geography), 2)          AS country_avg_balance,
        RANK() OVER (PARTITION BY geography ORDER BY balance DESC)    AS rank_in_country
    FROM customers
)
SELECT
    geography,
    balance_quartile,
    COUNT(*)                                          AS total_customers,
    SUM(exited)                                       AS churned,
    ROUND(SUM(exited) * 100.0 / COUNT(*), 1)          AS churn_rate_pct,
    ROUND(AVG(balance), 2)                            AS avg_balance
FROM ranked
GROUP BY geography, balance_quartile
ORDER BY geography, balance_quartile;
