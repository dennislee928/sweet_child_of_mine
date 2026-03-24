# Wazuh：僅 Agent vs 完整 Central 叢集

## 本 repo 預設

- 使用 [integrations/wazuh-agent](../integrations/wazuh-agent) 將節點／workload 事件轉送到**叢集外的** Wazuh Manager。
- 與 [wazuh-integration.md](./wazuh-integration.md) 說明一致：不在此 lab 內再跑一套完整的 Wazuh Indexer / Dashboard，以免與 OpenSearch 角色重疊。

## 何時考慮 full Wazuh central（in-cluster）

- 你需要與 Wazuh 生態系深度整合的 **SIEM 規則、活躍回應、合規報表**，且願意獨立維運第二套儲存與儀表板。
- 有可用的節點與儲存預算（Indexer、Manager、Dashboard 皆為 stateful／高資源元件）。

## 若採 in-cluster full stack 的實作方向（未內建於 base）

- 新增獨立 overlay，例如 `k8s/overlays/wazuh-central/`，或採官方／社群 Helm chart。
- 明確劃分資料面：高頻 exchange／Suricata／Kafka 事件仍以本 repo 的 OpenSearch 為查詢平面；Wazuh 專注於其 agent 與內建模組事件，避免雙寫同一用途索引。
- 評估與現有 Cilium policy 的 DNS／egress 允許清單，以及與 Kafka、OpenSearch 的網路分段是否衝突。

## 建議決策

- **研究／欺騙 lab**：維持 **external manager + in-cluster agent** 即可。
- **要完整企業 SIEM 體驗**：另開叢集或獨立命名空間做 Wazuh central，並以文件化 SLO／成本為準入條件。
