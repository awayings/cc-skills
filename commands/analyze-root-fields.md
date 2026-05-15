使用 `analyzing-root-field-access` skill 分析指定方法的入口参数根字段读写模式。

分析目标：`METHOD_SIGNATURE`（例如 `OrderBusinessServiceImpl.addGoodsOrder`）
入口参数类型：`PARAM_TYPE`（例如 `ReserveGoodsOrderData`）
参数变量名：`PARAM_NAME`（例如 `rgovo`）

请按以下步骤执行：

1. 定位目标方法，确定其所在文件和行号
2. 用 grep 查找参数变量在文件中的所有 `getXxx()` / `setXxx()` 调用
3. 追踪参数的下游传递路径，确定所有接收该参数的方法
4. 在每个下游方法中重复步骤 2
5. 按代码执行时序排列所有访问点
6. 对每个根字段判断：首次操作是读还是写？后续有无反向操作？
7. 将字段分为四类：只读不写 / 先读后写 / 先写后读 / 未使用
8. 输出完整的 markdown 分析报告，包含调用链概览、每类字段列表及精确的文件行号引用
