package com.amap.flutter.map.overlays.cluster;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.Message;
import android.util.Log;
import android.util.LruCache;
import android.util.TypedValue;
import android.view.Gravity;
import android.widget.FrameLayout;
import android.widget.TextView;

import com.amap.api.maps.AMap;
import com.amap.api.maps.AMapUtils;
import com.amap.api.maps.model.BitmapDescriptor;
import com.amap.api.maps.model.BitmapDescriptorFactory;
import com.amap.api.maps.model.CameraPosition;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.model.LatLngBounds;
import com.amap.api.maps.model.Marker;
import com.amap.api.maps.model.MarkerOptions;
import com.amap.api.maps.model.animation.AlphaAnimation;
import com.amap.api.maps.model.animation.Animation;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Created by yiyi.qi on 16/10/10.
 * 整体设计采用了两个线程,一个线程用于计算组织聚合数据,一个线程负责处理Marker相关操作
 */
public class ClusterOverlay implements AMap.OnCameraChangeListener,
        AMap.OnMarkerClickListener {
    private AMap mAMap;
    private Context mContext;
    private Map<String, ClusterItem> mClusterItems;
    private List<Cluster> mClusters;
    private int mClusterSize;
    private ClusterClickListener mClusterClickListener;
    private ClusterRender mClusterRender;
    private List<Marker> mAddMarkers = new ArrayList<>();
    private LruCache<Integer, BitmapDescriptor> mLruCache;
    private HandlerThread mMarkerHandlerThread = new HandlerThread("addMarker");
    private HandlerThread mSignClusterThread = new HandlerThread("calculateCluster");
    private Handler mMarkerhandler;
    private Handler mSignClusterHandler;
    private boolean mIsCanceled = false;

    /**
     * 构造函数
     *
     * @param amap
     * @param context
     */
    public ClusterOverlay(AMap amap, Context context) {
        this(amap, null, 200, context);
    }

    /**
     * 构造函数
     *
     * @param amap
     * @param clusterSize 聚合范围的大小（指点像素单位距离内的点会聚合到一个点显示）
     * @param context
     */
    public ClusterOverlay(AMap amap, int clusterSize, Context context) {
        this(amap, null, clusterSize, context);
    }

    /**
     * 构造函数,批量添加聚合元素时,调用此构造函数
     *
     * @param amap
     * @param clusterItems 聚合元素
     * @param clusterSize
     * @param context
     */
    public ClusterOverlay(AMap amap, Map<String, ClusterItem> clusterItems, int clusterSize, Context context) {
        //默认最多会缓存80张图片作为聚合显示元素图片,根据自己显示需求和app使用内存情况,可以修改数量
        mLruCache = new LruCache<Integer, BitmapDescriptor>(16) {
            protected void entryRemoved(boolean evicted, Integer key, BitmapDescriptor oldValue, BitmapDescriptor newValue) {
                reycleBitmap(oldValue.getBitmap());
            }
        };
        if (clusterItems != null) {
            mClusterItems = clusterItems;
        } else {
            mClusterItems = new HashMap<String, ClusterItem>();
        }
        mContext = context;
        mClusters = new ArrayList<Cluster>();
        this.mAMap = amap;
        mClusterSize = clusterSize;
        amap.setOnCameraChangeListener(this);
        amap.setOnMarkerClickListener(this);
        initThreadHandler();
        assignClusters();
    }

    private void reycleBitmap(Bitmap bitmap) {
        if (bitmap == null) {
            return;
        }
        //高版本不调用recycle
        if (Build.VERSION.SDK_INT <= 10) {
            if (!bitmap.isRecycled()) {
                bitmap.recycle();
            }
        }
    }

    /**
     * 设置聚合点的点击事件
     *
     * @param clusterClickListener
     */
    public void setOnClusterClickListener(ClusterClickListener clusterClickListener) {
        mClusterClickListener = clusterClickListener;
    }

    /**
     * 添加聚合点
     *
     * @param item
     */
    public void addClusterItem(ClusterItem item) {
        Message message = Message.obtain();
        message.what = SignClusterHandler.ADD_CLUSTER;
        message.obj = item;
        mSignClusterHandler.sendMessage(message);
    }

    public void addClusterItem(Map<String, ClusterItem> items) {
        Message message = Message.obtain();
        message.what = SignClusterHandler.ADD_CLUSTERS;
        message.obj = items;
        mSignClusterHandler.sendMessage(message);
    }

    public void removeClusterItem(String id) {
        Message message = Message.obtain();
        message.what = SignClusterHandler.REMOVE_CLUSTER;
        message.obj = id;
        mSignClusterHandler.sendMessage(message);
    }

    public void removeClusterItem(List<String> items) {
        Message message = Message.obtain();
        message.what = SignClusterHandler.REMOVE_CLUSTERS;
        message.obj = items;
        mSignClusterHandler.sendMessage(message);
    }

    /**
     * 设置聚合元素的渲染样式，不设置则默认为气泡加数字形式进行渲染
     *
     * @param render
     */
    public void setClusterRenderer(ClusterRender render) {
        mClusterRender = render;
    }

    public void onDestroy() {
        mIsCanceled = true;
        mSignClusterHandler.removeCallbacksAndMessages(null);
        mMarkerhandler.removeCallbacksAndMessages(null);
        mSignClusterThread.quit();
        mMarkerHandlerThread.quit();
        for (Marker marker : mAddMarkers) {
            marker.remove();

        }
        mAddMarkers.clear();
        mLruCache.evictAll();
    }

    //初始化Handler
    private void initThreadHandler() {
        mMarkerHandlerThread.start();
        mSignClusterThread.start();
        mMarkerhandler = new MarkerHandler(mMarkerHandlerThread.getLooper());
        mSignClusterHandler = new SignClusterHandler(mSignClusterThread.getLooper());
    }

    @Override
    public void onCameraChange(CameraPosition arg0) {


    }

    private float zoom = 0;
    @Override
    public void onCameraChangeFinish(CameraPosition arg0) {
        if (zoom != arg0.zoom) {
            zoom = arg0.zoom;
            assignClusters();
        }
    }

    //点击事件
    @Override
    public boolean onMarkerClick(Marker arg0) {
        if (mClusterClickListener == null) {
            return true;
        }
        Cluster cluster= (Cluster) arg0.getObject();
        if(cluster!=null){
            mClusterClickListener.onClick(arg0, cluster);
            return true;
        }
        return false;
    }


    /**
     * 将聚合元素添加至地图上
     */
    private void addClusterToMap(List<Cluster> clusters) {
        for (Marker marker : mAddMarkers) {
            if (!marker.isRemoved()) {
                marker.remove();
            }
        }

        for (Cluster cluster : clusters) {
            addSingleClusterToMap(cluster);
        }
    }

    /**
     * 将单个聚合元素添加至地图显示
     *
     * @param cluster
     */
    private void addSingleClusterToMap(Cluster cluster) {
        LatLng latlng = cluster.getCenterLatLng();
        MarkerOptions markerOptions = new MarkerOptions();
        markerOptions.anchor(0.5f, 0.5f)
                .icon(getBitmapDes(cluster))
                .position(latlng).rotateAngle(getRotateAngle(cluster));
        Marker marker = mAMap.addMarker(markerOptions);
        marker.setObject(cluster);

        cluster.setMarker(marker);
        mAddMarkers.add(marker);

    }

    private void calculateClusters() {
        mIsCanceled = false;
        mClusters.clear();
        LatLngBounds visibleBounds = mAMap.getProjection().getVisibleRegion().latLngBounds;
        Collection<ClusterItem> values = mClusterItems.values();
        for (ClusterItem clusterItem : values) {
            if (mIsCanceled) {
                return;
            }
            LatLng latlng = clusterItem.getPosition();
            if (visibleBounds.contains(latlng)) {
                Cluster cluster = getCluster(latlng, mClusters);
                if (cluster == null) {
                    cluster = new Cluster(latlng);
                    mClusters.add(cluster);
                }
                cluster.addClusterItem(clusterItem);

            }
        }

        //复制一份数据，规避同步
        List<Cluster> clusters = new ArrayList<Cluster>();
        clusters.addAll(mClusters);
        Message message = Message.obtain();
        message.what = MarkerHandler.ADD_CLUSTER_LIST;
        message.obj = clusters;
        if (mIsCanceled) {
            return;
        }
        mMarkerhandler.sendMessage(message);
    }

    /**
     * 对点进行聚合
     */
    private void assignClusters() {
        mIsCanceled = true;
        mSignClusterHandler.removeMessages(SignClusterHandler.CALCULATE_CLUSTER);
        mSignClusterHandler.sendEmptyMessage(SignClusterHandler.CALCULATE_CLUSTER);
    }

    /**
     * 在已有的聚合基础上，对添加的单个元素进行聚合
     *
     * @param clusterItem
     */
    private void calculateSingleCluster(ClusterItem clusterItem) {
        LatLngBounds visibleBounds = mAMap.getProjection().getVisibleRegion().latLngBounds;
        LatLng latlng = clusterItem.getPosition();
        if (!visibleBounds.contains(latlng)) {
            return;
        }
        Cluster cluster = getCluster(latlng, mClusters);
        if (cluster != null) {
            cluster.addClusterItem(clusterItem);
            Message message = Message.obtain();
            message.what = MarkerHandler.UPDATE_SINGLE_CLUSTER;

            message.obj = cluster;
            mMarkerhandler.removeMessages(MarkerHandler.UPDATE_SINGLE_CLUSTER);
            mMarkerhandler.sendMessageDelayed(message, 5);
        } else {
            cluster = new Cluster(latlng);
            mClusters.add(cluster);
            cluster.addClusterItem(clusterItem);
            Message message = Message.obtain();
            message.what = MarkerHandler.ADD_SINGLE_CLUSTER;
            message.obj = cluster;
            mMarkerhandler.sendMessage(message);
        }
    }

    private void calculateSingleCluster(Collection<ClusterItem> clusterItems) {
        for (ClusterItem clusterItem : clusterItems)
            calculateSingleCluster(clusterItem);
    }

    /**
     * 根据一个点获取是否可以依附的聚合点，没有则返回null
     *
     * @param latLng
     * @return
     */
    private Cluster getCluster(LatLng latLng, List<Cluster>clusters) {
        float mClusterDistance = mAMap.getScalePerPixel() * mClusterSize;
        for (Cluster cluster : clusters) {
            LatLng clusterCenterPoint = cluster.getCenterLatLng();
            double distance = AMapUtils.calculateLineDistance(latLng, clusterCenterPoint);
            if (distance < mClusterDistance && mAMap.getCameraPosition().zoom < 19) {
                return cluster;
            }
        }
        return null;
    }


    /**
     * 获取每个聚合点的绘制样式
     */
    private BitmapDescriptor getBitmapDes(Cluster cluster) {
        int num = cluster.getClusterCount();
        if (num == 1) {
            return cluster.getClusterItems().get(0).getIcon();
        } else {
            BitmapDescriptor bitmapDescriptor = mLruCache.get(num);
            if (bitmapDescriptor == null) {
                TextView textView = new TextView(mContext);
                String tile = String.valueOf(num);
                textView.setText(tile);
                textView.setGravity(Gravity.CENTER);
                textView.setTextColor(Color.WHITE);
                textView.setLayoutParams(new FrameLayout.LayoutParams(200, 200));
                textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
                Drawable drawable;
                if (mClusterRender != null && (drawable = mClusterRender.getDrawAble(num)) != null) {
                    textView.setBackgroundDrawable(drawable);
                    bitmapDescriptor = BitmapDescriptorFactory.fromView(textView);
                    mLruCache.put(num, bitmapDescriptor);
                }
            }
            return bitmapDescriptor;
        }
    }

    private float getRotateAngle(Cluster cluster) {
        if (cluster.getClusterCount() == 1) {
            return cluster.getClusterItems().get(0).getRotation();
        } else {
            return 0;
        }
    }

    /**
     * 更新已加入地图聚合点的样式
     */
    private void updateCluster(Cluster cluster) {
        Marker marker = cluster.getMarker();
        marker.setIcon(getBitmapDes(cluster));
    }


//-----------------------辅助内部类用---------------------------------------------

    /**
     * marker渐变动画，动画结束后将Marker删除
     */
    class MyAnimationListener implements Animation.AnimationListener {
        private  List<Marker> mRemoveMarkers ;

        MyAnimationListener(List<Marker> removeMarkers) {
            mRemoveMarkers = new ArrayList<>(removeMarkers);
        }

        @Override
        public void onAnimationStart() {

        }

        @Override
        public void onAnimationEnd() {
            for(Marker marker:mRemoveMarkers){
                if (marker.isRemoved()) {
                    break;
                }
                marker.remove();
            }
            mRemoveMarkers.clear();
        }
    }

    /**
     * 处理market添加，更新等操作
     */
    class MarkerHandler extends Handler {

        static final int ADD_CLUSTER_LIST = 0;

        static final int ADD_SINGLE_CLUSTER = 1;

        static final int UPDATE_SINGLE_CLUSTER = 2;

        MarkerHandler(Looper looper) {
            super(looper);
        }

        public void handleMessage(Message message) {

            switch (message.what) {
                case ADD_CLUSTER_LIST:
                    List<Cluster> clusters = (List<Cluster>) message.obj;
                    addClusterToMap(clusters);
                    break;
                case ADD_SINGLE_CLUSTER:
                    Cluster cluster = (Cluster) message.obj;
                    addSingleClusterToMap(cluster);
                    break;
                case UPDATE_SINGLE_CLUSTER:
                    Cluster updateCluster = (Cluster) message.obj;
                    updateCluster(updateCluster);
                    break;
            }
        }
    }

    /**
     * 处理聚合点算法线程
     */
    class SignClusterHandler extends Handler {
        static final int CALCULATE_CLUSTER = 0;
        static final int ADD_CLUSTER = 1;
        static final int ADD_CLUSTERS= 2;
        static final int REMOVE_CLUSTER = 3;
        static final int REMOVE_CLUSTERS= 4;

        SignClusterHandler(Looper looper) {
            super(looper);
        }

        public void handleMessage(Message message) {
            switch (message.what) {
                case CALCULATE_CLUSTER:
                    calculateClusters();
                    break;
                case ADD_CLUSTER: {
                    ClusterItem item = (ClusterItem) message.obj;
                    mClusterItems.put(item.getId(), item);
                    Log.i("yiyi.qi", "calculate single cluster");
                    calculateSingleCluster(item);
                }
                    break;
                case ADD_CLUSTERS: {
                    Map<String, ClusterItem> items = (Map<String, ClusterItem>) message.obj;
                    mClusterItems.putAll(items);
                    Log.i("yiyi.qi", "calculate single cluster");
                    calculateSingleCluster(items.values());
                }
                    break;
                case REMOVE_CLUSTER: {
                    String id = (String) message.obj;
                    mClusterItems.remove(id);
                    Log.i("yiyi.qi", "calculate single cluster");
                    calculateClusters();
                }
                    break;
                case REMOVE_CLUSTERS: {
                    List<String> items = (List<String>) message.obj;
                    for (String id : items) {
                        mClusterItems.remove(id);
                    }
                    Log.i("yiyi.qi", "calculate single cluster");
                    calculateClusters();
                    break;
                }
            }
        }
    }
}
