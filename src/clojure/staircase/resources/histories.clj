(ns staircase.resources.histories
  (:use staircase.protocols
        staircase.helpers
        [clojure.tools.logging :only (info)])
  (:require staircase.sql
            staircase.resources
            [honeysql.helpers :refer
              (select merge-select from where merge-where
               left-join group order-by merge-order-by)]
            [honeysql.core :as hsql]
            [staircase.resources.schema :as schema]
            [com.stuartsierra.component :as component]
            [clojure.java.jdbc :as sql]))

(defn- build-history [row & rows]
  (let [init (-> row
                 (assoc :steps (if (:step_id row) [(:step_id row)] []))
                 (dissoc :step_id))
        f #(update-in %1 [:steps] conj (:step_id %2))]
    (reduce f init rows)))

(def table-spec (merge schema/histories schema/history-step))

(defn- base-history-query []
  (-> (select :h.id :h.title :h.created_at :h.description :h.owner)
      (from [:histories :h])
      (left-join [:history_step :hs] [:= :h.id :hs.history_id])
      (where [:= :h.owner :?user])
      (order-by [:h.created_at :desc])))

(defn- all-history-query []
  (-> (base-history-query)
      (merge-select [:%count.hs.* :steps])
      (group :h.id :h.title :h.created_at :h.description :h.owner)
      (hsql/format :params staircase.resources/context)))

(defn- one-history-query [history]
  (-> (base-history-query)
      (merge-select :hs.step_id)
      (merge-where [:= :h.id :?history])
      (merge-order-by [:hs.created_at :desc])
      (hsql/format :params (assoc staircase.resources/context :history history))))

(defrecord HistoryResource [db]
  component/Lifecycle

  (start [component]
    (staircase.sql/create-tables
      (:connection db)
      table-spec)
    component)

  (stop [component] component)

  Resource

  (get-all [histories]
    (sql/query (:connection db) (all-history-query)))

  (exists? [_ id] (staircase.sql/exists-with-owner (:connection db) :histories id (:user staircase.resources/context)))

  (get-one [histories id]
    (when-let [uuid (string->uuid id)]
      (sql/query
        (:connection db)
        (one-history-query uuid)
        :result-set-fn #(if (empty? %) nil (apply build-history %)))))

  (update [_ id doc] (staircase.sql/update-owned-entity
                       (:connection db)
                       :histories
                       id (:user staircase.resources/context)
                       (dissoc doc :created_at "created_at")))

  (delete [histories id]
    (when-let [uuid (string->uuid id)]
      (sql/with-db-transaction [conn (:connection db)]
        (sql/delete! conn :history_step
                     ["history_id=?" uuid])
        (sql/delete! conn :histories
                     ["id=? and owner=?" uuid (:user staircase.resources/context)])
        ;; TODO - delete orphaned steps?
        ))
    nil)

  (create [histories doc]
    (let [id (new-id)
          created-at (or (:created_at doc) (sql-now))
          values (assoc (dissoc doc :owner :created_at)
                        "id" id
                        "created_at" created-at
                        "owner" (:user staircase.resources/context))]
      (sql/insert! (:connection db) :histories values)
      id)))

(defn new-history-resource [& {:keys [db]}] (map->HistoryResource {:db db}))

