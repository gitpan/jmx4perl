package org.cpan.jmx4perl.handler;

import org.cpan.jmx4perl.JmxRequest;

import javax.management.*;
import java.util.*;

/**
 * @author roland
 * @since Jun 12, 2009
 */
public class ListHandler extends RequestHandler {
    public JmxRequest.Type getType() {
        return JmxRequest.Type.LIST;
    }

    @Override
    public boolean handleAllServersAtOnce() {
        return true;
    }

    @Override
    public Object handleRequest(Set<MBeanServer> pServers, JmxRequest request)
            throws InstanceNotFoundException {
        try {
            Map<String /* domain */,
                    Map<String /* props */,
                            Map<String /* attribute/operation */,
                                                                List<String /* names */>>>> ret =
                    new HashMap<String, Map<String, Map<String, List<String>>>>();
            for (MBeanServer server : pServers) {
                for (Object nameObject : server.queryNames((ObjectName) null,(QueryExp) null)) {
                    ObjectName name = (ObjectName) nameObject;
                    MBeanInfo mBeanInfo = server.getMBeanInfo(name);

                    Map mBeansMap = getOrCreateMap(ret,name.getDomain());
                    Map mBeanMap = getOrCreateMap(mBeansMap,name.getCanonicalKeyPropertyListString());

                    addAttributes(mBeanMap, mBeanInfo);
                    addOperations(mBeanMap, mBeanInfo);

                    // Trim if needed
                    if (mBeanMap.size() == 0) {
                        mBeansMap.remove(name.getCanonicalKeyPropertyListString());
                        if (mBeansMap.size() == 0) {
                            ret.remove(name.getDomain());
                        }
                    }
                }
            }
            return ret;
        } catch (ReflectionException e) {
            throw new IllegalStateException("Internal error while retrieving list: " + e,e);
        } catch (IntrospectionException e) {
            throw new IllegalStateException("Internal error while retrieving list: " + e,e);
        }

    }

    private void addOperations(Map pMBeanMap, MBeanInfo pMBeanInfo) {
        // Extract operations
        Map opMap = new HashMap();
        for (MBeanOperationInfo opInfo : pMBeanInfo.getOperations()) {
            Map map = new HashMap();
            List argList = new ArrayList();
            for (MBeanParameterInfo paramInfo :  opInfo.getSignature()) {
                Map args = new HashMap();
                args.put("desc",paramInfo.getDescription());
                args.put("name",paramInfo.getName());
                args.put("type",paramInfo.getType());
                argList.add(args);
            }
            map.put("args",argList);
            map.put("ret",opInfo.getReturnType());
            map.put("desc",opInfo.getDescription());
            opMap.put(opInfo.getName(),map);
        }
        if (opMap.size() > 0) {
            pMBeanMap.put("op",opMap);
        }
    }

    private void addAttributes(Map pMBeanMap, MBeanInfo pMBeanInfo) {
        // Extract atributes
        Map attrMap = new HashMap();
        for (MBeanAttributeInfo attrInfo : pMBeanInfo.getAttributes()) {
            Map map = new HashMap();
            map.put("type",attrInfo.getType());
            map.put("desc",attrInfo.getDescription());
            map.put("rw",new Boolean(attrInfo.isWritable() && attrInfo.isReadable()));
            attrMap.put(attrInfo.getName(),map);
        }
        if (attrMap.size() > 0) {
            pMBeanMap.put("attr",attrMap);
        }
    }

    private Map getOrCreateMap(Map pMap, String pKey) {
        Map nMap = (Map) pMap.get(pKey);
        if (nMap == null) {
            nMap = new HashMap();
            pMap.put(pKey,nMap);
        }
        return nMap;
    }

    // will not be called
    @Override
    public Object handleRequest(MBeanServer server, JmxRequest request) throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
        return null;
    }



}
