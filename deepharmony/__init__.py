from deepharmony.graph import get_default_graph
from deepharmony.scalar.dtypes import FQDtype

def get_tensor(shape, name=None, dtype=FQDtype.FP32, trainable=True, data=None):
    g = get_default_graph()
    return g.tensor(shape=shape, name=name, dtype=dtype, trainable=trainable, data=data)
